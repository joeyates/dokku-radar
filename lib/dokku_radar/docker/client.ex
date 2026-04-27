defmodule DokkuRadar.Docker.Client do
  require Logger

  @socket_path "/var/run/docker.sock"

  @callback list_containers() :: {:ok, [map()]} | {:error, term()}
  @callback container_stats(String.t()) :: {:ok, map()} | {:error, term()}
  @callback container_inspect(String.t()) :: {:ok, map()} | {:error, term()}

  def list_containers(opts \\ []) do
    Logger.debug("Fetching container list from Docker")

    case opts |> base_req() |> Req.get(url: "/containers/json", params: [all: true]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.info("Fetched container list from Docker", count: length(body))
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Docker list_containers returned non-200",
          status: status,
          body: inspect(body)
        )

        {:error, {status, body}}

      {:error, reason} ->
        Logger.warning("Docker list_containers failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  def container_stats(container_id, opts \\ []) do
    Logger.debug("Fetching container stats from Docker", container_id: container_id)

    case opts
         |> base_req()
         |> Req.get(
           url: "/containers/:id/stats",
           path_params: [id: container_id],
           params: [stream: false, "one-shot": true]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.debug("Fetched container stats from Docker", container_id: container_id)
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Docker container_stats returned non-200",
          container_id: container_id,
          status: status,
          body: inspect(body)
        )

        {:error, {status, body}}

      {:error, reason} ->
        Logger.warning("Docker container_stats failed",
          container_id: container_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def container_inspect(container_id, opts \\ []) do
    Logger.debug("Inspecting container via Docker", container_id: container_id)

    case opts
         |> base_req()
         |> Req.get(url: "/containers/:id/json", path_params: [id: container_id]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.debug("Fetched container inspect from Docker", container_id: container_id)
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Docker container_inspect for container #{container_id} returned non-200",
          container_id: container_id,
          status: status,
          body: inspect(body)
        )

        {:error, {status, body}}

      {:error, reason} ->
        Logger.warning("Docker container_inspect failed",
          container_id: container_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp base_req(opts) do
    [
      base_url: "http://localhost",
      unix_socket: @socket_path,
      retry: false
    ]
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
