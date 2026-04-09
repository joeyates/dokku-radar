defmodule DokkuRadar.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test
  import Mox

  setup :verify_on_exit!

  @opts DokkuRadar.Router.init(collector: DokkuRadar.Collector.Mock)

  describe "GET /metrics" do
    test "returns 200 with prometheus text format" do
      metrics = [
        %{
          name: "dokku_app_processes_running",
          type: :gauge,
          help: "Running processes",
          samples: [
            %{labels: %{"app" => "my-app", "process_type" => "web"}, value: 1}
          ]
        }
      ]

      expect(DokkuRadar.Collector.Mock, :collect, fn _opts -> {:ok, metrics} end)

      conn =
        :get
        |> conn("/metrics")
        |> DokkuRadar.Router.call(@opts)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
      assert conn.resp_body =~ "dokku_app_processes_running"
      assert conn.resp_body =~ "# HELP"
      assert conn.resp_body =~ "# TYPE"
    end

    test "returns 500 when collector fails" do
      expect(DokkuRadar.Collector.Mock, :collect, fn _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      conn =
        :get
        |> conn("/metrics")
        |> DokkuRadar.Router.call(@opts)

      assert conn.status == 500
      assert conn.resp_body =~ "collection failed"
    end
  end

  describe "GET /health" do
    test "returns 200 ok" do
      conn =
        :get
        |> conn("/health")
        |> DokkuRadar.Router.call(@opts)

      assert conn.status == 200
      assert conn.resp_body == "ok"
    end
  end

  describe "unknown routes" do
    test "returns 404" do
      conn =
        :get
        |> conn("/unknown")
        |> DokkuRadar.Router.call(@opts)

      assert conn.status == 404
      assert conn.resp_body == "not found"
    end
  end
end
