defmodule DokkuRadar.ServicePlugins.Behaviour do
  @callback list() :: {:ok, [String.t()]} | {:error, non_neg_integer(), term()}
end
