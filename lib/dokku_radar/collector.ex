defmodule DokkuRadar.Collector do
  @callback collect() :: {:ok, [map()]} | {:error, term()}

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
  @ps_report Application.compile_env(
               :dokku_radar,
               :"DokkuRadar.PsReport",
               DokkuRadar.PsReport
             )
  @ps_scale Application.compile_env(
               :dokku_radar,
               :"DokkuRadar.PsScale",
               DokkuRadar.PsScale
             )
  @git_report Application.compile_env(
                :dokku_radar,
                :"DokkuRadar.GitReport",
                DokkuRadar.GitReport
              )
  @service_cache Application.compile_env(
                   :dokku_radar,
                   :"DokkuRadar.ServiceCache",
                   DokkuRadar.ServiceCache
                 )

  def collect() do
    docker_client = @docker_client
    certs_client = @certs_client
    ps_report_client = @ps_report
    ps_scale_client = @ps_scale
    git_report_client = @git_report
    service_cache = @service_cache
    docker_opts = []

    Logger.debug("Starting metrics collection")

    case docker_client.list_containers(docker_opts) do
      {:error, reason} ->
        Logger.warning("Metrics collection failed: could not list containers",
          reason: inspect(reason)
        )

        {:error, reason}

      {:ok, containers} ->
        dokku_containers = Enum.filter(containers, &dokku_container?/1)
        app_names = dokku_containers |> Enum.map(&app_name/1) |> Enum.uniq()

        Logger.info("Collecting metrics",
          total_containers: length(containers),
          dokku_containers: length(dokku_containers),
          apps: length(app_names)
        )

        stats_by_id = fetch_all_stats(dokku_containers, docker_client, docker_opts)
        inspects_by_id = fetch_all_inspects(dokku_containers, docker_client, docker_opts)
        scales_by_app = fetch_all_scales(app_names, ps_scale_client)
        expiries_by_app = fetch_cert_expiries(certs_client)
        ps_entries = fetch_ps_entries(ps_report_client)
        git_reports_by_app = fetch_git_reports(app_names, git_report_client)
        cached_services = fetch_cached_services(service_cache)

        metrics = [
          processes_configured_metric(scales_by_app),
          processes_running_metric(ps_entries),
          container_state_metric(ps_entries),
          container_restarts_metric(dokku_containers, inspects_by_id),
          last_deploy_metric(git_reports_by_app),
          ssl_cert_expiry_metric(expiries_by_app),
          cpu_usage_metric(dokku_containers, stats_by_id),
          memory_usage_metric(dokku_containers, stats_by_id),
          service_linked_metric(cached_services),
          service_status_metric(cached_services)
        ]

        Logger.debug("Metrics collection complete")

        {:ok, metrics}
    end
  end

  defp dokku_container?(container) do
    container["Labels"]["com.dokku.app-name"] != nil
  end

  defp app_name(container) do
    container["Labels"]["com.dokku.app-name"]
  end

  defp container_name(container) do
    case container["Names"] do
      [name | _] -> String.trim_leading(name, "/")
      _ -> short_id(container)
    end
  end

  defp short_id(container) do
    String.slice(container["Id"], 0, 12)
  end

  defp fetch_all_stats(containers, docker_client, opts) do
    Map.new(containers, fn container ->
      id = container["Id"]
      {id, docker_client.container_stats(id, opts)}
    end)
  end

  defp fetch_all_inspects(containers, docker_client, opts) do
    Map.new(containers, fn container ->
      id = container["Id"]
      {id, docker_client.container_inspect(id, opts)}
    end)
  end

  defp fetch_all_scales(app_names, ps_scale_client) do
    Map.new(app_names, fn app ->
      {app, ps_scale_client.scale(app)}
    end)
  end

  defp fetch_cert_expiries(certs_client) do
    case certs_client.list() do
      {:ok, expiries} -> expiries
      {:error, _} -> %{}
    end
  end

  defp fetch_ps_entries(ps_report_client) do
    case ps_report_client.list() do
      {:ok, entries} -> entries
      {:error, _} -> []
    end
  end

  defp fetch_git_reports(app_names, git_report_client) do
    Map.new(app_names, fn app ->
      {app, git_report_client.report(app)}
    end)
  end

  defp processes_configured_metric(scales_by_app) do
    samples =
      Enum.flat_map(scales_by_app, fn
        {app, {:ok, scale}} ->
          Enum.map(scale, fn {process_type, count} ->
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

  defp processes_running_metric(ps_entries) do
    samples =
      ps_entries
      |> Enum.filter(&(&1.state == "running"))
      |> Enum.group_by(fn entry -> {entry.app, entry.process_type} end)
      |> Enum.map(fn {{app, pt}, entries} ->
        %{labels: %{"app" => app, "process_type" => pt}, value: length(entries)}
      end)

    %{
      name: "dokku_app_processes_running",
      type: :gauge,
      help: "Number of running processes per app and process type",
      samples: samples
    }
  end

  defp container_state_metric(ps_entries) do
    samples =
      Enum.map(ps_entries, fn entry ->
        %{
          labels: %{
            "app" => entry.app,
            "container_id" => entry.cid,
            "process_type" => entry.process_type,
            "process_index" => to_string(entry.process_index),
            "state" => entry.state
          },
          value: 1
        }
      end)

    %{
      name: "dokku_container_state",
      type: :gauge,
      help: "Container state (1 = current state as labeled)",
      samples: samples
    }
  end

  defp container_restarts_metric(dokku_containers, inspects_by_id) do
    samples =
      Enum.flat_map(dokku_containers, fn cont ->
        case inspects_by_id[cont["Id"]] do
          {:ok, inspect_data} ->
            [
              %{
                labels: %{
                  "app" => app_name(cont),
                  "container_id" => short_id(cont),
                  "container_name" => container_name(cont)
                },
                value: get_in(inspect_data, ["State", "RestartCount"]) || 0
              }
            ]

          _ ->
            []
        end
      end)

    %{
      name: "dokku_container_restarts_total",
      type: :counter,
      help: "Total number of container restarts",
      samples: samples
    }
  end

  defp last_deploy_metric(git_reports_by_app) do
    samples =
      Enum.flat_map(git_reports_by_app, fn
        {app, {:ok, ts}} ->
          [%{labels: %{"app" => app}, value: ts}]

        {_app, {:error, _}} ->
          []
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

  defp cpu_usage_metric(dokku_containers, stats_by_id) do
    samples =
      Enum.flat_map(dokku_containers, fn cont ->
        case stats_by_id[cont["Id"]] do
          {:ok, stats} ->
            total_ns = get_in(stats, ["cpu_stats", "cpu_usage", "total_usage"]) || 0

            [
              %{
                labels: %{"app" => app_name(cont), "container_id" => short_id(cont)},
                value: total_ns / 1_000_000_000
              }
            ]

          _ ->
            []
        end
      end)

    %{
      name: "dokku_app_cpu_usage_seconds_total",
      type: :counter,
      help: "Total CPU usage in seconds per container",
      samples: samples
    }
  end

  defp memory_usage_metric(dokku_containers, stats_by_id) do
    samples =
      Enum.flat_map(dokku_containers, fn cont ->
        case stats_by_id[cont["Id"]] do
          {:ok, stats} ->
            usage = get_in(stats, ["memory_stats", "usage"]) || 0

            [
              %{
                labels: %{"app" => app_name(cont), "container_id" => short_id(cont)},
                value: usage
              }
            ]

          _ ->
            []
        end
      end)

    %{
      name: "dokku_app_memory_usage_bytes",
      type: :gauge,
      help: "Current memory usage in bytes per container",
      samples: samples
    }
  end

  defp fetch_cached_services(service_cache) do
    case service_cache.service_links() do
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
