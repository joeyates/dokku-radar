defmodule DokkuRadar.ServiceCache.Behaviour do
  @callback service_links() :: {:ok, [map()]} | {:error, term()}
end
