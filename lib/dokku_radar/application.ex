defmodule DokkuRadar.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = children()

    opts = [strategy: :one_for_one, name: DokkuRadar.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children() do
    module_env = Application.get_env(:dokku_radar, __MODULE__, [])
    start_caches = Keyword.get(module_env, :start_caches, true)

    if start_caches do
      port = Application.get_env(:dokku_radar, :port, 9110)

      [
        {Task.Supervisor, name: DokkuRadar.TaskSupervisor},
        DokkuRadar.Docker.Cache,
        DokkuRadar.Git.Cache,
        DokkuRadar.Certs.Cache,
        DokkuRadar.Ps.Cache,
        DokkuRadar.Services.Cache,
        {Bandit, plug: DokkuRadar.Router, port: port}
      ]
    else
      []
    end
  end
end
