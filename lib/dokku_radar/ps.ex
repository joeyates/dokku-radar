defmodule DokkuRadar.Ps do
  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Ps.Cache",
           DokkuRadar.Ps.Cache
         )

  @callback list() ::
              {:ok, %{String.t() => DokkuRemote.Commands.Ps.Report.t()}} | {:error, term()}
  def list() do
    @cache.list()
  end

  @callback scale(String.t()) :: {:ok, DokkuRemote.Commands.Ps.Scale.t()} | {:error, term()}
  def scale(app_name) do
    @cache.scale(app_name)
  end
end
