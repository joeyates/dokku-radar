defmodule DokkuRadar.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:dokku_radar, :port, 9110)

    children = [
      {Task.Supervisor, name: DokkuRadar.TaskSupervisor},
      DokkuRadar.Git.Cache,
      DokkuRadar.Certs.Cache,
      DokkuRadar.Ps.Cache,
      DokkuRadar.Services.Cache,
      {Bandit, plug: DokkuRadar.Router, port: port}
    ]

    opts = [strategy: :one_for_one, name: DokkuRadar.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
