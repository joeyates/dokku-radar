import Config

app_name = :dokku_radar

ssh_certificate_path =
  System.get_env("SSH_CERTIFICATE_PATH") ||
    raise """
    environment variable SSH_CERTIFICATE_PATH is missing.
    For example: /data/.ssh/id_ed25519
    """

dokku_host =
  System.get_env("DOKKU_HOST") ||
    raise """
    environment variable DOKKU_HOST is missing
    """

port = "PORT" |> System.get_env("9110") |> String.to_integer()

config app_name, DokkuRadar.DokkuCli,
  dokku_host: dokku_host,
  ssh_certificate_path: ssh_certificate_path

config app_name, dokku_host: config(app_name, port: port)

config :dokku_remote, DokkuRemote.Ssh, %{
  dokku_host => %{
    "dokku" => [
      "-i",
      ssh_certificate_path,
      "-o",
      "BatchMode=yes",
      "-o",
      "StrictHostKeyChecking=no",
      "-o",
      "UserKnownHostsFile=/dev/null",
      "-o",
      "LogLevel=ERROR"
    ]
  }
}
