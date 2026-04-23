defmodule DokkuRadar.Certs.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  require Logger

  @commands_certs Application.compile_env(
                    :dokku_radar,
                    :"DokkuRemote.Commands.Certs",
                    DokkuRemote.Commands.Certs
                  )

  #################
  # Client API

  @callback list() :: {:ok, %{String.t() => DateTime.t()}} | {:error, term()}

  def list(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call(:list, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:list, _from, %{data: expiries} = state) do
    {:reply, {:ok, expiries}, state}
  end

  def handle_call(msg, from, state), do: super(msg, from, state)

  #################
  # Load

  @impl DokkuRadar.DokkuCli.Cache
  def load() do
    dokku_host = DokkuRadar.DokkuCli.dokku_host!()

    case @commands_certs.report(dokku_host) do
      {:ok, reports} ->
        expiries =
          reports
          |> Enum.flat_map(fn {app, report} ->
            case report.expires_at && DokkuRadar.Certs.Report.parse_expiry(report.expires_at) do
              {:ok, dt} -> [{app, dt}]
              _ -> []
            end
          end)
          |> Map.new()

        {:update, expiries}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run certs:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end
end
