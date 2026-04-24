defmodule DokkuRadar.Collector do
  require Logger

  @docker_client Application.compile_env(
                   :dokku_radar,
                   :"DokkuRadar.DockerClient",
                   DokkuRadar.DockerClient
                 )
  @certs_client Application.compile_env(
                  :dokku_radar,
                  :"DokkuRadar.Certs",
                  DokkuRadar.Certs
                )
  @ps_client Application.compile_env(
               :dokku_radar,
               :"DokkuRadar.Ps",
               DokkuRadar.Ps
             )
  @git_client Application.compile_env(
                :dokku_radar,
                :"DokkuRadar.Git",
                DokkuRadar.Git
              )
  @service_client Application.compile_env(
                    :dokku_radar,
                    :"DokkuRadar.Services",
                    DokkuRadar.Services
                  )

  @callback collect() :: {:ok, [map()]} | {:error, term()}
  def collect() do
    Logger.debug("Starting metrics collection")

    case @ps_client.list() do
      {:error, reason} ->
        Logger.warning("Metrics collection failed: could not fetch ps:report",
          reason: inspect(reason)
        )

        {:error, reason}

      {:ok, ps_reports} ->
        app_names = ps_reports |> Map.keys() |> Enum.uniq()

        Logger.info("Collecting metrics", apps: length(app_names))

        stats_by_id = fetch_all_stats(ps_reports)
        inspects_by_id = fetch_all_inspects(ps_reports)
        scales_by_app = fetch_all_scales(app_names)
        expiries_by_app = fetch_cert_expiries()
        timestamps_by_app = fetch_git_timestamps()
        cached_services = fetch_services()

        metrics = [
          processes_configured_metric(scales_by_app),
          processes_running_metric(ps_reports),
          container_state_metric(ps_reports),
          container_restarts_metric(ps_reports, inspects_by_id),
          last_deploy_metric(timestamps_by_app),
          ssl_cert_expiry_metric(expiries_by_app),
          cpu_usage_metric(ps_reports, stats_by_id),
          memory_usage_metric(ps_reports, stats_by_id),
          service_linked_metric(cached_services),
          service_status_metric(cached_services)
        ]

        Logger.debug("Metrics collection complete")

        {:ok, metrics}
    end
  end

  defp fetch_all_stats(ps_reports) do
    ps_reports
    |> Enum.flat_map(fn {_app_name, report} ->
      Enum.map(report.status_entries, fn entry ->
        {entry.cid, @docker_client.container_stats(entry.cid)}
      end)
    end)
    |> Map.new()
  end

  defp fetch_all_inspects(ps_reports) do
    ps_reports
    |> Enum.flat_map(fn {_app_name, report} ->
      Enum.map(report.status_entries, fn entry ->
        {entry.cid, @docker_client.container_inspect(entry.cid)}
      end)
    end)
    |> Map.new()
  end

  defp fetch_all_scales(app_names) do
    Map.new(app_names, fn app_name ->
      {app_name, @ps_client.scale(app_name)}
    end)
  end

  defp fetch_cert_expiries() do
    case @certs_client.list() do
      {:ok, expiries} -> expiries
      {:error, _} -> %{}
    end
  end

  defp fetch_git_timestamps() do
    case @git_client.last_deploy_timestamps() do
      {:ok, timestamps} ->
        timestamps
        |> Enum.filter(fn {_, value} -> is_integer(value) end)
        |> Enum.into(%{})

      {:error, _} ->
        %{}
    end
  end

  defp processes_configured_metric(scales_by_app) do
    samples =
      Enum.flat_map(scales_by_app, fn
        {app, {:ok, scale}} ->
          Enum.map(scale.proctypes, fn {process_type, count} ->
            %{labels: %{"app" => app, "process_type" => process_type}, value: count}
          end)

        {_app, {:error, _}} ->
          []
      end)

    %{
      name: "dokku_app_processes_configured",
      type: :gauge,
      help: "Number of configured processes per app and process type",
      samples: samples
    }
  end

  defp processes_running_metric(ps_reports) do
    samples =
      ps_reports
      |> Map.values()
      |> Enum.flat_map(fn report ->
        Enum.map(report.status_entries, fn entry ->
          %{app_name: report.app_name, process_name: entry.process_name, running: entry.running}
        end)
      end)
      |> Enum.filter(& &1.running)
      |> Enum.group_by(fn entry -> {entry.app_name, entry.process_name} end)
      |> Enum.map(fn {{app_name, process_name}, entries} ->
        %{labels: %{"app" => app_name, "process_type" => process_name}, value: length(entries)}
      end)

    %{
      name: "dokku_app_processes_running",
      type: :gauge,
      help: "Number of running processes per app and process type",
      samples: samples
    }
  end

  defp container_state_metric(ps_reports) do
    samples =
      Enum.flat_map(ps_reports, fn {_app_name, report} ->
        Enum.map(report.status_entries, fn entry ->
          state = if entry.running, do: "running", else: "exited"

          %{
            labels: %{
              "app" => report.app_name,
              "container_id" => entry.cid,
              "process_type" => entry.process_name,
              "process_index" => to_string(entry.index),
              "state" => state
            },
            value: 1
          }
        end)
      end)

    %{
      name: "dokku_container_state",
      type: :gauge,
      help: "Container state (1 = current state as labeled)",
      samples: samples
    }
  end

  defp container_restarts_metric(ps_reports, inspects_by_id) do
    samples =
      Enum.flat_map(ps_reports, fn {_app_name, report} ->
        Enum.flat_map(report.status_entries, fn entry ->
          case inspects_by_id[entry.cid] do
            {:ok, inspect_data} ->
              [
                %{
                  labels: %{
                    "app" => report.app_name,
                    "container_id" => entry.cid,
                    "process_type" => entry.process_name,
                    "process_index" => to_string(entry.index)
                  },
                  value: get_in(inspect_data, ["State", "RestartCount"]) || 0
                }
              ]

            _ ->
              []
          end
        end)
      end)

    %{
      name: "dokku_container_restarts_total",
      type: :counter,
      help: "Total number of container restarts",
      samples: samples
    }
  end

  defp last_deploy_metric(timestamps_by_app) do
    samples =
      Enum.map(timestamps_by_app, fn {app, ts} ->
        %{labels: %{"app" => app}, value: ts}
      end)

    %{
      name: "dokku_app_last_deploy_timestamp",
      type: :gauge,
      help: "Unix timestamp of the most recent deploy per app",
      samples: samples
    }
  end

  defp ssl_cert_expiry_metric(expiries_by_app) do
    samples =
      Enum.map(expiries_by_app, fn {app, expiry} ->
        %{labels: %{"app" => app}, value: DateTime.to_unix(expiry)}
      end)

    %{
      name: "dokku_ssl_cert_expiry_timestamp",
      type: :gauge,
      help: "Unix timestamp of SSL certificate expiry per app",
      samples: samples
    }
  end

  defp cpu_usage_metric(ps_reports, stats_by_id) do
    samples =
      Enum.flat_map(ps_reports, fn {_app_name, report} ->
        Enum.flat_map(report.status_entries, fn entry ->
          case stats_by_id[entry.cid] do
            {:ok, stats} ->
              total_ns = get_in(stats, ["cpu_stats", "cpu_usage", "total_usage"]) || 0

              [
                %{
                  labels: %{"app" => report.app_name, "container_id" => entry.cid},
                  value: total_ns / 1_000_000_000
                }
              ]

            _ ->
              []
          end
        end)
      end)

    %{
      name: "dokku_app_cpu_usage_seconds_total",
      type: :counter,
      help: "Total CPU usage in seconds per container",
      samples: samples
    }
  end

  defp memory_usage_metric(ps_reports, stats_by_id) do
    samples =
      Enum.flat_map(ps_reports, fn {_app_name, report} ->
        Enum.flat_map(report.status_entries, fn entry ->
          case stats_by_id[entry.cid] do
            {:ok, stats} ->
              usage = get_in(stats, ["memory_stats", "usage"]) || 0

              [
                %{
                  labels: %{"app" => report.app_name, "container_id" => entry.cid},
                  value: usage
                }
              ]

            _ ->
              []
          end
        end)
      end)

    %{
      name: "dokku_app_memory_usage_bytes",
      type: :gauge,
      help: "Current memory usage in bytes per container",
      samples: samples
    }
  end

  defp fetch_services() do
    case @service_client.service_links() do
      {:ok, services} -> services
      {:error, _} -> []
    end
  end

  defp service_linked_metric(services) do
    samples =
      Enum.flat_map(services, fn service ->
        Enum.map(service.links, fn app ->
          %{
            labels: %{
              "app" => app,
              "service_type" => service.type,
              "service_name" => service.name
            },
            value: 1
          }
        end)
      end)

    %{
      name: "dokku_service_linked",
      type: :gauge,
      help: "1 if the app has the named service linked",
      samples: samples
    }
  end

  defp service_status_metric(services) do
    samples =
      Enum.map(services, fn service ->
        value = if service.status == "running", do: 1, else: 0

        %{
          labels: %{
            "service_type" => service.type,
            "service_name" => service.name
          },
          value: value
        }
      end)

    %{
      name: "dokku_service_status",
      type: :gauge,
      help: "1 if the service is running, 0 if stopped",
      samples: samples
    }
  end
end
