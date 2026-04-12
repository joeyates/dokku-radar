defmodule DokkuRadar.Router do
  use Plug.Router

  require Logger

  @collector Application.compile_env(:dokku_radar, :"DokkuRadar.Collector", DokkuRadar.Collector)

  plug(:match)
  plug(:dispatch)

  get "/metrics" do
    Logger.debug("#{__MODULE__}, get /metrics")

    case @collector.collect() do
      {:ok, metrics} ->
        body = DokkuRadar.PrometheusFormatter.format(metrics)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)

      {:error, reason} ->
        Logger.error("collector.collect failed: #{inspect(reason)}")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "collection failed")
    end
  end

  get "/health" do
    send_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
