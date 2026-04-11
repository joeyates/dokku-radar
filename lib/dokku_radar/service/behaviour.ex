defmodule DokkuRadar.Service.Behaviour do
  @callback links(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
end
