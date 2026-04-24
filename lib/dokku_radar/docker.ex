defmodule DokkuRadar.Docker do
  @callback container_stats(String.t()) :: {:ok, map()} | {:error, term()}
  @callback container_inspect(String.t()) :: {:ok, map()} | {:error, term()}

  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Docker.Cache",
           DokkuRadar.Docker.Cache
         )

  def container_stats(id) do
    @cache.container_stats(id)
  end

  def container_inspect(id) do
    @cache.container_inspect(id)
  end
end
