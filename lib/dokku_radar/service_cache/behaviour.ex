defmodule DokkuRadar.ServiceCache.Behaviour do
  @callback get() :: {:ok, [map()]} | {:error, term()}
end
