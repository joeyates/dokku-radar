# Optional Next Steps

## Add node_exporter for Host-level Metrics

Deploy [node_exporter](https://github.com/prometheus/node_exporter) as
another Dokku app on the `monitoring` network, then uncomment the
`node_exporter` job in `prometheus.yml`.
