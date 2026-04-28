defmodule DokkuRadar.Docker do
  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Docker.Cache",
           DokkuRadar.Docker.Cache
         )

  @callback container_stats(String.t()) :: {:ok, map()} | {:error, term()}
  def container_stats(id) do
    @cache.container_stats(id)
  end

  @callback container_inspect(String.t()) :: {:ok, map()} | {:error, term()}
  def container_inspect(id) do
    @cache.container_inspect(id)
  end
end
