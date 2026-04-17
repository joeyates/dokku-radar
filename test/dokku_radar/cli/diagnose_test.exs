defmodule DokkuRadar.CLI.DiagnoseTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias DokkuRadar.CLI.Diagnose
  alias DokkuRemote.App

  @dokku_host "test.example.com"
  @dokku_app "dokku-radar"
  @app %App{dokku_host: @dokku_host, dokku_app: @dokku_app}

  setup :verify_on_exit!

  @ssh_host_dir "/var/lib/dokku/data/storage/dokku-radar/.ssh"
  @container_dir "/data/.ssh"
  @private_key_path "#{@ssh_host_dir}/id_ed25519"

  describe "run/1" do
    test "prints a passing line when all web processes are running" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, ""}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "Checking dokku-app is running... ✅"
    end

    test "prints a failing line when a web process is not running" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "exited",
             cid: "abc"
           }
         ]}
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, ""}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "App running"
    end

    test "prints a failing line when ps report fails" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:error, "ssh: Connection refused", 255}
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, ""}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "App running"
    end

    test "prints a passing line when the private key mount is configured" do
      expect_app_running()
      expect_key_mount_ok()
      expect_key_file_exists()
      expect_all_networks_monitoring()
      expect_prometheus_running()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "Checking private key directory is mounted in container... ✅"
    end

    test "prints a failing line when the mount is not configured" do
      expect_app_running()

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "storage:report",
                                                       @dokku_app,
                                                       "--storage-run-mounts"
                                                     ],
                                                     [] ->
        {:ok, ""}
      end)

      expect_key_file_exists()
      expect_all_networks_monitoring()
      expect_prometheus_running()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "Private key: mount"
    end

    test "prints a failing line when the storage report command fails" do
      expect_app_running()

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "storage:report",
                                                       @dokku_app,
                                                       "--storage-run-mounts"
                                                     ],
                                                     [] ->
        {:error, "ssh: Connection refused", 255}
      end)

      expect_key_file_exists()
      expect_all_networks_monitoring()
      expect_prometheus_running()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "Private key: mount"
    end

    test "prints a passing line when the key file exists" do
      expect_app_running()
      expect_key_mount_ok()
      expect_key_file_exists()
      expect_all_networks_monitoring()
      expect_prometheus_running()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "Checking private key is installed on host... ✅"
    end

    test "prints a failing line when the key file does not exist" do
      expect_app_running()
      expect_key_mount_ok()

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "test",
                                                     ["-f", @private_key_path],
                                                     [] ->
        {:error, "", 1}
      end)

      expect_all_networks_monitoring()
      expect_prometheus_running()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "Private key: file"
    end

    test "prints passing lines when all apps are on monitoring network" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      expect_key_mount_ok()
      expect_key_file_exists()
      expect_all_networks_monitoring()

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "Checking dokku-radar is on monitoring network... ✅"
      assert output =~ "Checking prometheus is on monitoring network... ✅"
      assert output =~ "Checking grafana is on monitoring network... ✅"
    end

    test "prints a failing line when an app is not on monitoring network" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      expect_key_mount_ok()
      expect_key_file_exists()

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "dokku-radar",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:ok, "monitoring"}
      end)

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "prometheus",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:ok, "other-network"}
      end)

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "grafana",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:ok, "monitoring"}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "prometheus"
    end

    test "prints a failing line when the network report command fails" do
      stub(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      expect_key_mount_ok()
      expect_key_file_exists()

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "dokku-radar",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:error, "ssh: Connection refused", 255}
      end)

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "prometheus",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:ok, "monitoring"}
      end)

      expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                     "dokku",
                                                     [
                                                       "network:report",
                                                       "grafana",
                                                       "--network-attach-post-deploy"
                                                     ],
                                                     [] ->
        {:ok, "monitoring"}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "dokku-radar"
    end

    test "prints a passing line when all prometheus web processes are running" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, 2, fn host ->
        case host do
          @dokku_host ->
            {:ok,
             [
               %{
                 app: "dokku-radar",
                 process_type: "web",
                 process_index: 1,
                 state: "running",
                 cid: "abc"
               },
               %{
                 app: "prometheus",
                 process_type: "web",
                 process_index: 1,
                 state: "running",
                 cid: "def"
               }
             ]}
        end
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, "monitoring"}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "Checking prometheus is running... ✅"
    end

    test "prints a failing line when a prometheus web process is not running" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, 2, fn host ->
        case host do
          @dokku_host ->
            {:ok,
             [
               %{
                 app: "dokku-radar",
                 process_type: "web",
                 process_index: 1,
                 state: "running",
                 cid: "abc"
               },
               %{
                 app: "prometheus",
                 process_type: "web",
                 process_index: 1,
                 state: "exited",
                 cid: "def"
               }
             ]}
        end
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, "monitoring"}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "Prometheus running"
    end

    test "prints a failing line when the prometheus ps report fails" do
      expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:ok,
         [
           %{
             app: "dokku-radar",
             process_type: "web",
             process_index: 1,
             state: "running",
             cid: "abc"
           }
         ]}
      end)

      expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
        {:error, "ssh: Connection refused", 255}
      end)

      stub(DokkuRemote.Root.Command.Mock, :run, fn _host, _cmd, _params, _opts ->
        {:ok, "monitoring"}
      end)

      output = capture_io(fn -> Diagnose.run(@app) end)
      assert output =~ "❌"
      assert output =~ "Prometheus running"
    end
  end

  defp expect_app_running() do
    expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
      {:ok,
       [
         %{
           app: "dokku-radar",
           process_type: "web",
           process_index: 1,
           state: "running",
           cid: "abc"
         }
       ]}
    end)
  end

  defp expect_key_mount_ok() do
    expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                   "dokku",
                                                   [
                                                     "storage:report",
                                                     @dokku_app,
                                                     "--storage-run-mounts"
                                                   ],
                                                   [] ->
      {:ok, "#{@ssh_host_dir}:#{@container_dir}"}
    end)
  end

  defp expect_key_file_exists() do
    expect(DokkuRemote.Root.Command.Mock, :run, fn @dokku_host,
                                                   "test",
                                                   ["-f", @private_key_path],
                                                   [] ->
      {:ok, ""}
    end)
  end

  defp expect_all_networks_monitoring() do
    expect(DokkuRemote.Root.Command.Mock, :run, 3, fn @dokku_host,
                                                      "dokku",
                                                      [
                                                        "network:report",
                                                        _,
                                                        "--network-attach-post-deploy"
                                                      ],
                                                      [] ->
      {:ok, "monitoring"}
    end)
  end

  defp expect_prometheus_running() do
    expect(DokkuRemote.Commands.Ps.Mock, :report, fn @dokku_host ->
      {:ok,
       [
         %{
           app: "prometheus",
           process_type: "web",
           process_index: 1,
           state: "running",
           cid: "def"
         }
       ]}
    end)
  end
end
