defmodule DokkuRadar.Git do
  @callback last_deploy_timestamps() ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  @cache Application.compile_env(
           :dokku_radar,
           :"DokkuRadar.Git.Cache",
           DokkuRadar.Git.Cache
         )

  def last_deploy_timestamps() do
    @cache.last_deploy_timestamps()
  end
end
