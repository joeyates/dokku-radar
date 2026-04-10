defmodule DokkuRadar.DokkuCliTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.DokkuCli

  @plugin_list_output """
  =====> Installed plugins
    access          deployed access:
    letsencrypt     deployed letsencrypt:latest
    postgres        deployed postgres:latest
    redis           deployed redis:latest
    scheduler-simple deployed scheduler-simple:latest
  """

  @postgres_list_output """
  =====> Postgres services
  NAME            VERSION          STATUS     EXPOSED PORTS  LINKS
  my-database     postgres:14.13   running                   my-app
  another-db      postgres:14.13   running                   app1,app2
  orphan-db       postgres:14.13   stopped                   
  """

  describe "list_service_types/1" do
    test "returns known service types found in plugin list" do
      cmd_fn = fn "ssh", _args, _opts -> {@plugin_list_output, 0} end

      assert {:ok, types} = DokkuCli.list_service_types(cmd_fn: cmd_fn)

      assert "postgres" in types
      assert "redis" in types
    end

    test "ignores non-service plugins" do
      cmd_fn = fn "ssh", _args, _opts -> {@plugin_list_output, 0} end

      assert {:ok, types} = DokkuCli.list_service_types(cmd_fn: cmd_fn)

      refute "access" in types
      refute "letsencrypt" in types
      refute "scheduler-simple" in types
    end

    test "passes the configured SSH host" do
      cmd_fn = fn "ssh", args, _opts ->
        assert Enum.member?(args, "dokku@myhost.example.com")
        {@plugin_list_output, 0}
      end

      DokkuCli.list_service_types(cmd_fn: cmd_fn, host: "myhost.example.com")
    end

    test "returns error on non-zero exit code" do
      cmd_fn = fn "ssh", _args, _opts -> {"ssh: connect to host bad port 22: Connection refused", 255} end

      assert {:error, _reason} = DokkuCli.list_service_types(cmd_fn: cmd_fn)
    end
  end

  describe "list_services/2" do
    test "returns services with name, status, and links" do
      cmd_fn = fn "ssh", _args, _opts -> {@postgres_list_output, 0} end

      assert {:ok, services} = DokkuCli.list_services("postgres", cmd_fn: cmd_fn)

      assert length(services) == 3
    end

    test "parses running service linked to a single app" do
      cmd_fn = fn "ssh", _args, _opts -> {@postgres_list_output, 0} end

      assert {:ok, services} = DokkuCli.list_services("postgres", cmd_fn: cmd_fn)

      svc = Enum.find(services, &(&1.name == "my-database"))
      assert svc.status == "running"
      assert svc.links == ["my-app"]
    end

    test "parses service linked to multiple apps" do
      cmd_fn = fn "ssh", _args, _opts -> {@postgres_list_output, 0} end

      assert {:ok, services} = DokkuCli.list_services("postgres", cmd_fn: cmd_fn)

      svc = Enum.find(services, &(&1.name == "another-db"))
      assert svc.links == ["app1", "app2"]
    end

    test "parses stopped service with no links" do
      cmd_fn = fn "ssh", _args, _opts -> {@postgres_list_output, 0} end

      assert {:ok, services} = DokkuCli.list_services("postgres", cmd_fn: cmd_fn)

      svc = Enum.find(services, &(&1.name == "orphan-db"))
      assert svc.status == "stopped"
      assert svc.links == []
    end

    test "returns error on non-zero exit code" do
      cmd_fn = fn "ssh", _args, _opts -> {"Unknown service type: badtype", 1} end

      assert {:error, _reason} = DokkuCli.list_services("badtype", cmd_fn: cmd_fn)
    end
  end
end
