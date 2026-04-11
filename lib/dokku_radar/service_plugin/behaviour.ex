defmodule DokkuRadar.ServicePlugin.Behaviour do
  @callback services(String.t()) :: {:ok, [String.t()]} | {:error, non_neg_integer(), term()}
end
