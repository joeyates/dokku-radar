import Config

app_name = :dokku_radar

config app_name, port: 9876

config app_name,
  System: System.Mock,
  "DokkuRemote.Commands.Certs": DokkuRemote.Commands.Certs.Mock,
  "DokkuRemote.Commands.Git": DokkuRemote.Commands.Git.Mock,
  "DokkuRemote.Commands.Plugin": DokkuRemote.Commands.Plugin.Mock,
  "DokkuRemote.Commands.Postgres": DokkuRemote.Commands.Postgres.Mock,
  "DokkuRemote.Commands.Ps": DokkuRemote.Commands.Ps.Mock,
  "DokkuRemote.Commands.Redis": DokkuRemote.Commands.Redis.Mock,
  "DokkuRadar.DockerClient": DokkuRadar.DockerClient.Mock,
  "DokkuRadar.Certs": DokkuRadar.Certs.Mock,
  "DokkuRadar.Certs.Cache": DokkuRadar.Certs.Cache.Mock,
  "DokkuRadar.Git.Cache": DokkuRadar.Git.Cache.Mock,
  "DokkuRadar.Git": DokkuRadar.Git.Mock,
  "DokkuRadar.Git.Report": DokkuRadar.Git.Report.Mock,
  "DokkuRadar.Ps.Cache": DokkuRadar.Ps.Cache.Mock,
  "DokkuRadar.Ps": DokkuRadar.Ps.Mock,
  "DokkuRadar.Collector": DokkuRadar.Collector.Mock,
  "DokkuRadar.Services.Service": DokkuRadar.Services.Service.Mock,
  "DokkuRadar.Services.ServicePlugin": DokkuRadar.Services.ServicePlugin.Mock,
  "DokkuRadar.Services.ServicePlugins": DokkuRadar.Services.ServicePlugins.Mock,
  "DokkuRadar.Services.Cache": DokkuRadar.Services.Cache.Mock,
  "DokkuRadar.Services": DokkuRadar.Services.Mock

config :dokku_radar, DokkuRadar.DokkuCli, dokku_host: "test.example.com"
