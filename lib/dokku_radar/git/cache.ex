defmodule DokkuRadar.Git.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  require Logger

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

  #################
  # Client API

  @callback last_deploy_timestamps() ::
              {:ok, %{String.t() => non_neg_integer()}} | {:error, term()}

  def last_deploy_timestamps(server \\ __MODULE__) do
    GenServer.call(server, :last_deploy_timestamps)
  end

  #################
  # Handle Client Calls

  @impl GenServer
  def handle_call(:last_deploy_timestamps, _from, %{data: nil} = state) do
    {:reply, {:error, :no_data}, state}
  end

  def handle_call(:last_deploy_timestamps, _from, %{data: timestamps} = state) do
    {:reply, {:ok, timestamps}, state}
  end

  def handle_call(msg, from, state), do: super(msg, from, state)

  #################
  # Load

  @impl DokkuRadar.DokkuCli.Cache
  def load() do
    case @dokku_cli.call("git:report") do
      {:ok, output} ->
        {:update, DokkuRadar.Git.Report.parse(output)}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run git:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end
end
