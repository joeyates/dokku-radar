defmodule DokkuRadar.DokkuCli.Behaviour do
  @callback list_service_types(keyword()) :: {:ok, [String.t()]} | {:error, term()}
  @callback list_services(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
end
