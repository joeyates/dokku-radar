defmodule DokkuRadar.Services do
  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Services.Cache",
           DokkuRadar.Services.Cache
         )

  @callback service_links() :: {:ok, [map()]} | {:error, term()}
  def service_links() do
    @cache.service_links()
  end
end
