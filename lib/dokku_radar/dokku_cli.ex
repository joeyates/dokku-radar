defmodule DokkuRadar.DokkuCli do
  require Logger

  @system Application.compile_env(:dokku_radar, :System, System)

  @callback call(String.t()) ::
              {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  @callback call(String.t(), [String.t()]) ::
              {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def call(command, args \\ []) do
    Logger.debug("Calling Dokku command #{inspect(command)}, with args #{inspect(args)}")

    case @system.cmd("ssh", ssh_args(command) ++ args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {output, exit_code} ->
        {:error, output, exit_code}
    end
  end

  defp ssh_args(command) do
    host = dokku_host!()
    ssh_certificate_path = ssh_certificate_path!()

    [
      "-i",
      ssh_certificate_path,
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

  defp module_env!() do
    Application.fetch_env!(:dokku_radar, __MODULE__)
  end

  def dokku_host!() do
    Keyword.fetch!(module_env!(), :dokku_host)
  end

  defp ssh_certificate_path!() do
    Keyword.fetch!(module_env!(), :ssh_certificate_path)
  end
end
