defmodule DokkuRadar.Git.Report do
  @callback app_timestamps() :: {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}
  def app_timestamps() do
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    case DokkuRemote.Commands.Git.report(dokku_host) do
      {:ok, report} ->
        timestamps =
          report
          |> Map.values()
          |> Enum.map(fn app_report ->
            {app_report.app_name, app_report.last_updated_at}
          end)
          |> Map.new()

        {:ok, timestamps}

      {:error, output, exit_code} ->
        {:error, output, exit_code}
    end
  end
end
