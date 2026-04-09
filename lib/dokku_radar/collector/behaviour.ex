defmodule DokkuRadar.Collector.Behaviour do
  @callback collect(keyword()) :: {:ok, [map()]} | {:error, term()}
end
