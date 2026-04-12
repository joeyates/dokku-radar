import Config

app_name = :dokku_radar

config app_name, port: 9876

config app_name,
  System: System.Mock,
  "DokkuRadar.DockerClient": DokkuRadar.DockerClient.Mock,
  "DokkuRadar.FilesystemReader": DokkuRadar.FilesystemReader.Mock,
  "DokkuRadar.ServiceCache": DokkuRadar.ServiceCache.Mock,
  "DokkuRadar.Collector": DokkuRadar.Collector.Mock,
  "DokkuRadar.DokkuCli": DokkuRadar.DokkuCli.Mock,
  "DokkuRadar.Service": DokkuRadar.Service.Mock,
  "DokkuRadar.ServicePlugin": DokkuRadar.ServicePlugin.Mock,
  "DokkuRadar.ServicePlugins": DokkuRadar.ServicePlugins.Mock
