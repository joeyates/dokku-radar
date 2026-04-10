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

1. Open Grafana in your browser
2. Go to **Dashboards** and open the Dokku Radar dashboard
3. Click the dashboard settings icon (⚙) → **JSON Model**
4. Replace the contents with the updated `grafana/dashboard.json` and click
   **Save changes**

Alternatively, delete the existing dashboard and re-import the JSON file:

1. Go to **Dashboards → New → Import**
2. Click **Upload JSON file**
3. Select `grafana/dashboard.json`
4. Select the Prometheus datasource
5. Click **Import**

## Update App Images

To pull the latest image for any app:

```bash
dokku git:from-image dokku-radar ghcr.io/joeyates/dokku-radar:latest
dokku git:from-image prometheus quay.io/prometheus/prometheus:latest
dokku git:from-image grafana grafana/grafana:latest
```

Each command triggers a rebuild and redeploy of that app.
