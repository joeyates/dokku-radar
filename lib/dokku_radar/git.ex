defmodule DokkuRadar.Git do
  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Git.Cache",
           DokkuRadar.Git.Cache
         )

  @callback last_deploy_timestamps() ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}
  def last_deploy_timestamps() do
    @cache.last_deploy_timestamps()
  end
end
