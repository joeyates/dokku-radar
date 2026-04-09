defmodule DokkuRadar.DockerClient do
  @behaviour DokkuRadar.DockerClient.Behaviour

  @socket_path "/var/run/docker.sock"

  @impl true
  def list_containers(opts \\ []) do
    case opts |> base_req() |> Req.get(url: "/containers/json", params: [all: true]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def container_stats(container_id, opts \\ []) do
    case opts
         |> base_req()
         |> Req.get(
           url: "/containers/:id/stats",
           path_params: [id: container_id],
           params: [stream: false, "one-shot": true]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
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
