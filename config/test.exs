import Config

app_name = :dokku_radar

config app_name, port: 9876

config app_name,
  System: System.Mock,
  "DokkuRadar.DockerClient": DokkuRadar.DockerClient.Mock,
  "DokkuRadar.Certs": DokkuRadar.Certs.Mock,
  "DokkuRadar.Certs.Cache": DokkuRadar.Certs.Cache.Mock,
  "DokkuRadar.PsReport": DokkuRadar.PsReport.Mock,
  "DokkuRadar.PsScale": DokkuRadar.PsScale.Mock,
  "DokkuRadar.GitReport": DokkuRadar.GitReport.Mock,
  "DokkuRadar.Git.Cache": DokkuRadar.Git.Cache.Mock,
  "DokkuRadar.Git": DokkuRadar.Git.Mock,
  "DokkuRadar.Ps.Cache": DokkuRadar.Ps.Cache.Mock,
  "DokkuRadar.Ps": DokkuRadar.Ps.Mock,
  "DokkuRadar.Collector": DokkuRadar.Collector.Mock,
  "DokkuRadar.DokkuCli": DokkuRadar.DokkuCli.Mock,
  "DokkuRadar.Services.Service": DokkuRadar.Services.Service.Mock,
  "DokkuRadar.Services.ServicePlugin": DokkuRadar.Services.ServicePlugin.Mock,
  "DokkuRadar.Services.ServicePlugins": DokkuRadar.Services.ServicePlugins.Mock,
  "DokkuRadar.Services.Cache": DokkuRadar.Services.Cache.Mock,
  "DokkuRadar.Services": DokkuRadar.Services.Mock
