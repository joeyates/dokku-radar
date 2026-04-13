import Config

app_name = :dokku_radar

config app_name, port: 9876

config app_name,
  System: System.Mock,
  "DokkuRadar.DockerClient": DokkuRadar.DockerClient.Mock,
  "DokkuRadar.Certs": DokkuRadar.Certs.Mock,
  "DokkuRadar.PsReport": DokkuRadar.PsReport.Mock,
  "DokkuRadar.PsScale": DokkuRadar.PsScale.Mock,
  "DokkuRadar.GitReport": DokkuRadar.GitReport.Mock,
  "DokkuRadar.ServiceCache": DokkuRadar.ServiceCache.Mock,
  "DokkuRadar.Collector": DokkuRadar.Collector.Mock,
  "DokkuRadar.DokkuCli": DokkuRadar.DokkuCli.Mock,
  "DokkuRadar.Service": DokkuRadar.Service.Mock,
  "DokkuRadar.ServicePlugin": DokkuRadar.ServicePlugin.Mock,
  "DokkuRadar.ServicePlugins": DokkuRadar.ServicePlugins.Mock,
  "DokkuRadar.Services.Service": DokkuRadar.Services.Service.Mock,
  "DokkuRadar.Services.ServicePlugin": DokkuRadar.Services.ServicePlugin.Mock,
  "DokkuRadar.Services.ServicePlugins": DokkuRadar.Services.ServicePlugins.Mock,
  "DokkuRadar.Services.Cache": DokkuRadar.Services.Cache.Mock,
  "DokkuRadar.Services": DokkuRadar.Services.Mock
