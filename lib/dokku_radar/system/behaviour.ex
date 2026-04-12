defmodule DokkuRadar.System.Behaviour do
  @callback cmd(String.t(), [String.t()], keyword()) :: {String.t(), non_neg_integer()}
end
