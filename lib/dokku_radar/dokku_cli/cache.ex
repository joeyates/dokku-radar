defmodule DokkuRadar.DokkuCli.Cache do
  @callback load() :: {:update, term()} | {:error, term()}

  defmacro __using__(opts) do
    interval = Keyword.fetch!(opts, :interval)

    quote do
      use GenServer

      require Logger

      @behaviour DokkuRadar.DokkuCli.Cache

      #################
      # Client API

      def start_link(opts \\ []) do
        {name, opts} = Keyword.pop(opts, :name, __MODULE__)
        gen_server_opts = if name, do: [name: name], else: []
        GenServer.start_link(__MODULE__, opts, gen_server_opts)
      end

      def status(server \\ __MODULE__) do
        GenServer.call(server, :status)
      end

      def refresh(server \\ __MODULE__) do
        GenServer.cast(server, :refresh)
      end

      #################
      # Setup

      @impl GenServer
      def init(opts) do
        refresh_interval = Keyword.get(opts, :refresh_interval, unquote(interval))

        state = %{
          data: nil,
          refresh_interval: refresh_interval,
          update_task: nil,
          error: nil
        }

        {:ok, state, {:continue, :load}}
      end

      @impl GenServer
      def handle_continue(:load, %{update_task: nil} = state) do
        {:noreply, initiate_load(state)}
      end

      #################
      # Handle Client Calls

      @impl GenServer
      def handle_call(:status, _from, state) do
        status =
          cond do
            not is_nil(state.update_task) -> :updating
            not is_nil(state.error) -> :error
            not is_nil(state.data) -> :ready
            true -> :unexpected
          end

        {:reply, status, state}
      end

      defoverridable handle_call: 3

      #################
      # Refresh

      @impl GenServer
      def handle_cast(:refresh, %{update_task: nil} = state) do
        Logger.debug("#{__MODULE__}.handle_cast(:refresh) — starting load")
        {:noreply, initiate_load(state)}
      end

      def handle_cast(:refresh, state) do
        Logger.warning("#{__MODULE__}.handle_cast(:refresh) — load already running, ignoring")
        {:noreply, state}
      end

      #################
      # Task completion/failure

      @impl GenServer
      def handle_info({ref, {:update, data}}, %{update_task: %Task{ref: ref}} = state) do
        state = demonitor(state)
        state = %{state | data: data, error: nil}
        state = maybe_enqueue_refresh(state)
        {:noreply, state}
      end

      def handle_info({ref, {:error, reason}}, %{update_task: %Task{ref: ref}} = state) do
        Logger.error("#{__MODULE__} failed to load: #{inspect(reason)}")
        state = state |> demonitor() |> maybe_enqueue_refresh()
        {:noreply, %{state | error: reason}}
      end

      def handle_info(
            {:DOWN, ref, :process, _pid, reason},
            %{update_task: %Task{ref: ref}} = state
          ) do
        Logger.error("#{__MODULE__} load task failed: #{inspect(reason)}")
        {:noreply, %{state | update_task: nil}}
      end

      def handle_info(:refresh, %{update_task: nil} = state) do
        {:noreply, initiate_load(state)}
      end

      def handle_info(:refresh, %{update_task: %Task{} = task} = state) do
        Logger.warning(
          "#{__MODULE__} handle_info(:refresh) received when load is running — restarting"
        )

        Task.shutdown(task, :brutal_kill)
        state = demonitor(state)
        {:noreply, initiate_load(state)}
      end

      defoverridable handle_info: 2

      #################
      # load/0 default — must be overridden by using module

      def load(), do: raise("#{__MODULE__} must implement load/0")
      defoverridable load: 0

      #################
      # Private helpers

      defp initiate_load(state) do
        task = Task.Supervisor.async_nolink(DokkuRadar.TaskSupervisor, fn -> load() end)
        %{state | update_task: task}
      end

      defp demonitor(%{update_task: task} = state) do
        Process.demonitor(task.ref, [:flush])
        %{state | update_task: nil}
      end

      defp maybe_enqueue_refresh(%{refresh_interval: nil} = state), do: state

      defp maybe_enqueue_refresh(%{refresh_interval: ms} = state) do
        Process.send_after(self(), :refresh, ms)
        state
      end
    end
  end
end
