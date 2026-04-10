# Maintenance

## Update Prometheus Configuration

Edit `prometheus/prometheus.yml` locally, then copy it to the host and restart:

```bash
scp prometheus/prometheus.yml root@$DOKKU_HOST:/var/lib/dokku/data/storage/prometheus/config/prometheus.yml
dokku ps:restart prometheus
```

## Update the Grafana Dashboard

The dashboard is not provisioned automatically — it is imported manually via
the Grafana UI. To update it after making changes to `grafana/dashboard.json`:

First, look up the real datasource UID:

```bash
DS_UID=$(curl -sf -H "Authorization: Bearer $GRAFANA_SERVICE_ACCOUNT_TOKEN" "https://$GRAFANA_DOMAIN/api/datasources/name/prometheus" | jq -r '.uid')
```

Then post to the import endpoint with overwrite:

```bash
curl -sf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $GRAFANA_SERVICE_ACCOUNT_TOKEN" https://$GRAFANA_DOMAIN/api/dashboards/import -d "{\"dashboard\": $(cat dashboard.json), "overwrite": true, "inputs": [{"name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "$DS_UID"}]}"
```

Alternatively, delete the existing dashboard and re-import the JSON file:

1. Go to **Dashboards → New → Import**
2. Click **Upload JSON file**
3. Select `grafana/dashboard.json`
4. Select the Prometheus datasource
5. Click **Import**

## Update App Images

To pull the latest image:

Check the latest version of dokku-radar here: https://github.com/joeyates/dokku-radar/pkgs/container/dokku-radar

```bash
dokku git:from-image dokku-radar ghcr.io/joeyates/dokku-radar:{VERSION}
dokku git:from-image prometheus quay.io/prometheus/prometheus:latest
dokku git:from-image grafana grafana/grafana:latest
```

Each command triggers a rebuild and redeploy of that app.
