defmodule DokkuRadar.DokkuCli do
  @behaviour DokkuRadar.DokkuCli.Behaviour

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

  @impl true
  def list_service_types(opts \\ []) do
    cmd_fn = Keyword.get(opts, :cmd_fn, &System.cmd/3)
    host = Keyword.get(opts, :host, Application.get_env(:dokku_radar, :dokku_host, @default_host))

    case cmd_fn.("ssh", ssh_args(host, "plugin:list"), stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, parse_service_types(output)}

      {output, exit_code} ->
        {:error, {exit_code, output}}
    end
  end

  @impl true
  def list_services(service_type, opts \\ []) do
    cmd_fn = Keyword.get(opts, :cmd_fn, &System.cmd/3)
    host = Keyword.get(opts, :host, Application.get_env(:dokku_radar, :dokku_host, @default_host))

    case cmd_fn.("ssh", ssh_args(host, "#{service_type}:list"), stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, parse_services(output)}

      {output, exit_code} ->
        {:error, {exit_code, output}}
    end
  end

  defp ssh_args(host, command) do
    [
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
    |> Enum.reject(&(&1 |> String.trim() |> String.starts_with?("NAME")))
    |> Enum.map(&parse_service_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_service_line(line) do
    case String.split(line) do
      [name, _version, status | rest] ->
        links =
          rest
          |> Enum.reject(&(&1 == ""))
          |> Enum.flat_map(&String.split(&1, ","))
          |> Enum.reject(&(&1 == ""))

        %{name: name, status: status, links: links}

      _ ->
        nil
    end
  end
end
