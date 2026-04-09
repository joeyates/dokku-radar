defmodule DokkuRadar.PrometheusFormatterTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.PrometheusFormatter

  describe "format/1" do
    test "formats a gauge metric with HELP, TYPE, and samples" do
      metrics = [
        %{
          name: "dokku_app_processes_configured",
          type: :gauge,
          help: "Number of configured processes per app and process type",
          samples: [
            %{labels: %{"app" => "my-app", "process_type" => "web"}, value: 2}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~
               "# HELP dokku_app_processes_configured Number of configured processes per app and process type\n"

      assert output =~ "# TYPE dokku_app_processes_configured gauge\n"
      assert output =~ ~s(dokku_app_processes_configured{app="my-app",process_type="web"} 2\n)
    end

    test "formats a counter metric" do
      metrics = [
        %{
          name: "dokku_container_restarts_total",
          type: :counter,
          help: "Total number of container restarts",
          samples: [
            %{labels: %{"app" => "my-app", "container_id" => "abc123"}, value: 5}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ "# TYPE dokku_container_restarts_total counter\n"
      assert output =~ ~s(dokku_container_restarts_total{app="my-app",container_id="abc123"} 5\n)
    end

    test "formats multiple samples for one metric" do
      metrics = [
        %{
          name: "dokku_app_processes_configured",
          type: :gauge,
          help: "Configured processes",
          samples: [
            %{labels: %{"app" => "my-app", "process_type" => "web"}, value: 2},
            %{labels: %{"app" => "my-app", "process_type" => "worker"}, value: 1}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      lines = String.split(output, "\n", trim: true)
      sample_lines = Enum.reject(lines, &String.starts_with?(&1, "#"))
      assert length(sample_lines) == 2
    end

    test "formats multiple metrics separated by blank lines" do
      metrics = [
        %{
          name: "metric_a",
          type: :gauge,
          help: "Help A",
          samples: [%{labels: %{"app" => "a"}, value: 1}]
        },
        %{
          name: "metric_b",
          type: :counter,
          help: "Help B",
          samples: [%{labels: %{"app" => "b"}, value: 2}]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ "metric_a"
      assert output =~ "metric_b"

      # Metrics are separated by a blank line
      assert output =~ "\n\n"
    end

    test "omits samples but keeps HELP and TYPE when samples list is empty" do
      metrics = [
        %{
          name: "dokku_ssl_cert_expiry_timestamp",
          type: :gauge,
          help: "SSL certificate expiry",
          samples: []
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ "# HELP dokku_ssl_cert_expiry_timestamp SSL certificate expiry\n"
      assert output =~ "# TYPE dokku_ssl_cert_expiry_timestamp gauge\n"
      refute output =~ "dokku_ssl_cert_expiry_timestamp{"
    end

    test "formats float values without trailing zeros" do
      metrics = [
        %{
          name: "dokku_app_cpu_usage_seconds_total",
          type: :counter,
          help: "CPU usage",
          samples: [
            %{labels: %{"app" => "my-app"}, value: 2.5}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ ~s(dokku_app_cpu_usage_seconds_total{app="my-app"} 2.5\n)
    end

    test "formats integer values without decimal point" do
      metrics = [
        %{
          name: "dokku_app_memory_usage_bytes",
          type: :gauge,
          help: "Memory usage",
          samples: [
            %{labels: %{"app" => "my-app"}, value: 104_857_600}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ ~s(dokku_app_memory_usage_bytes{app="my-app"} 104857600\n)
    end

    test "sorts label keys alphabetically" do
      metrics = [
        %{
          name: "dokku_container_state",
          type: :gauge,
          help: "State",
          samples: [
            %{
              labels: %{
                "state" => "running",
                "container_name" => "my-app.web.1",
                "app" => "my-app",
                "container_id" => "abc123"
              },
              value: 1
            }
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~
               ~s(dokku_container_state{app="my-app",container_id="abc123",container_name="my-app.web.1",state="running"} 1\n)
    end

    test "escapes backslash, newline, and double-quote in label values" do
      metrics = [
        %{
          name: "test_metric",
          type: :gauge,
          help: "Test",
          samples: [
            %{labels: %{"label" => "val\\ue\nwith\"quotes"}, value: 1}
          ]
        }
      ]

      output = PrometheusFormatter.format(metrics)

      assert output =~ ~s(test_metric{label="val\\\\ue\\nwith\\"quotes"} 1\n)
    end

    test "returns empty string for empty metrics list" do
      assert PrometheusFormatter.format([]) == ""
    end
  end
end
