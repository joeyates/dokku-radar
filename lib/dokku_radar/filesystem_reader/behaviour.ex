defmodule DokkuRadar.FilesystemReader.Behaviour do
  @callback app_scale(String.t(), keyword()) ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}
  @callback cert_expiry(String.t(), keyword()) :: {:ok, DateTime.t()} | {:error, term()}
end
