defmodule DokkuRadar.Certs.Cache do
  use DokkuRadar.DokkuCli.Cache, interval: :timer.minutes(10)

  require Logger

  @dokku_cli Application.compile_env(:dokku_radar, :"DokkuRadar.DokkuCli", DokkuRadar.DokkuCli)

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
    case @dokku_cli.call("certs:report") do
      {:ok, output} ->
        {:update, DokkuRadar.Certs.Report.parse(output)}

      {:error, output, exit_code} ->
        Logger.warning("Failed to run certs:report", exit_code: exit_code, output: output)
        {:error, {output, exit_code}}
    end
  end
end
