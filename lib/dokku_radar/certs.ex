defmodule DokkuRadar.Certs do
  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Certs.Cache",
           DokkuRadar.Certs.Cache
         )

  @callback list() :: {:ok, %{String.t() => DateTime.t()}} | {:error, term()}
  def list() do
    @cache.list()
  end
end
