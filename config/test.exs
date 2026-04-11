import Config

app_name = :dokku_radar

config app_name, port: 9876

config app_name,
  "DokkuRadar.Service": DokkuRadar.Service.Mock,
  "DokkuRadar.ServicePlugin": DokkuRadar.ServicePlugin.Mock,
  "DokkuRadar.ServicePlugins": DokkuRadar.ServicePlugins.Mock
