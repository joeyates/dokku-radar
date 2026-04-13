defmodule DokkuRadar.Ps do
  @callback list() :: {:ok, [map()]} | {:error, term()}
  @callback scale(String.t()) :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Ps.Cache",
           DokkuRadar.Ps.Cache
         )

  def list() do
    @cache.list()
  end

  def scale(app_name) do
    @cache.scale(app_name)
  end
end
