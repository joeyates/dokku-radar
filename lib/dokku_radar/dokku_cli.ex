defmodule DokkuRadar.DokkuCli do
  @behaviour DokkuRadar.DokkuCli.Behaviour

  require Logger

  @known_service_types ~w(
    elasticsearch
    mariadb
    memcached
    mongo
    mongodb
    mysql
    postgres
    rabbitmq
    redis
  )

  @default_host "localhost"
  @certificate_path "/data/.ssh/id_ed25519"

  @impl true
  def list_service_types(opts \\ []) do
    cmd_fn = Keyword.get(opts, :cmd_fn, &System.cmd/3)
    host = Keyword.get(opts, :host, Application.get_env(:dokku_radar, :dokku_host, @default_host))

    Logger.debug("Fetching Dokku plugin list via SSH", host: host)

    case cmd_fn.("ssh", ssh_args(host, "plugin:list"), stderr_to_stdout: true) do
      {output, 0} ->
        types = parse_service_types(output)
        Logger.info("Fetched Dokku service types", host: host, count: length(types))
        {:ok, types}

      {output, exit_code} ->
        Logger.warning("SSH call to list plugins failed",
          host: host,
          exit_code: exit_code,
          output: String.slice(output, 0, 200)
        )

        {:error, {exit_code, output}}
    end
  end

  @impl true
  def list_services(service_type, opts \\ []) do
    cmd_fn = Keyword.get(opts, :cmd_fn, &System.cmd/3)
    host = Keyword.get(opts, :host, Application.get_env(:dokku_radar, :dokku_host, @default_host))

    Logger.debug("Fetching Dokku service list via SSH", host: host, service_type: service_type)

    case cmd_fn.("ssh", ssh_args(host, "#{service_type}:list"), stderr_to_stdout: true) do
      {output, 0} ->
        services = parse_services(output)

        Logger.info("Fetched Dokku services",
          host: host,
          service_type: service_type,
          count: length(services)
        )

        {:ok, services}

      {output, exit_code} ->
        Logger.warning("SSH call to list services failed",
          host: host,
          service_type: service_type,
          exit_code: exit_code,
          output: String.slice(output, 0, 200)
        )

        {:error, {exit_code, output}}
    end
  end

  defp ssh_args(host, command) do
    [
      "-i",
      @certificate_path,
      "-o",
      "BatchMode=yes",
      "-o",
      "StrictHostKeyChecking=no",
      "-o",
      "UserKnownHostsFile=/dev/null",
      "-o",
      "LogLevel=ERROR",
      "dokku@#{host}",
      command
    ]
  end

  defp parse_service_types(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "====="))
    |> Enum.map(fn line ->
      line |> String.trim() |> String.split(~r/\s+/) |> List.first()
    end)
    |> Enum.filter(&(&1 in @known_service_types))
  end

  defp parse_services(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "====="))
  end
end
