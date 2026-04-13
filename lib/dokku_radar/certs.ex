defmodule DokkuRadar.Certs do
  @callback list() :: {:ok, %{String.t() => DateTime.t()}} | {:error, term()}

  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Certs.Cache",
           DokkuRadar.Certs.Cache
         )

  def list() do
    @cache.list()
  end
end
