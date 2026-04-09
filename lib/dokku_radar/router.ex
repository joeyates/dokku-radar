defmodule DokkuRadar.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/metrics" do
    collector = conn.private[:collector] || DokkuRadar.Collector

    case collector.collect([]) do
      {:ok, metrics} ->
        body = DokkuRadar.PrometheusFormatter.format(metrics)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)

      {:error, _reason} ->
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

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    collector = Keyword.get(opts, :collector)

    conn =
      if collector do
        Plug.Conn.put_private(conn, :collector, collector)
      else
        conn
      end

    super(conn, opts)
  end
end
