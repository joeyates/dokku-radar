defmodule DokkuRadar.DokkuCli do
  defp module_env!() do
    Application.fetch_env!(:dokku_radar, __MODULE__)
  end

  def dokku_host!() do
    Keyword.fetch!(module_env!(), :dokku_host)
  end
end
