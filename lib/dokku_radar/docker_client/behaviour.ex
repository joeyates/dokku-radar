defmodule DokkuRadar.DockerClient.Behaviour do
  @callback list_containers(keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback container_stats(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
