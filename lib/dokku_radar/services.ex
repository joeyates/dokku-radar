defmodule DokkuRadar.Services do
  @callback service_links() :: {:ok, [map()]} | {:error, term()}

  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Services.Cache",
           DokkuRadar.Services.Cache
         )

  def service_links() do
    @cache.service_links()
  end
end
