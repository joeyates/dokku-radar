# Setup Guide

This guide walks through deploying the complete Dokku monitoring stack:
**dokku-radar** (Prometheus exporter), **Prometheus**, and **Grafana** — all
running as Dokku apps on a shared private network.

## Prerequisites

Before starting, confirm:

- **Dokku** is installed (tested with Dokku 0.35+):
  ```bash
  dokku version
  ```
- **Network plugin** is available (ships with Dokku):
  ```bash
  dokku network:list
  ```
- **SSH access** — you can reach the host as both `dokku` and `root` users
- **`DOKKU_HOST`** is set in your local shell:
  ```bash
  export DOKKU_HOST=your-server.example.com
  ```

### Recommended Aliases

The commands below assume two local shell aliases:

| Alias | Command |
|---|---|
| `dokku` | `ssh -t dokku@$DOKKU_HOST "$@"` |
| `dokku-root` | `ssh -o LogLevel=QUIET -t root@$DOKKU_HOST dokku` |

## Customising Names

Every name used in this guide can be changed. If you do, update the
corresponding files and commands:

| Default Name | Used In |
|---|---|
| `monitoring` | Network name in all `dokku network:set` commands |
| `dokku-radar` | App name, GHCR image reference, `prometheus.yml` scrape target |
| `prometheus` | App name, Grafana datasource URL |
| `grafana` | App name |

**Important:** Changing an app name changes its internal network hostname.
For example, renaming `dokku-radar` to `my-exporter` means the Prometheus
scrape target becomes `my-exporter.web.1:9110` — update `prometheus.yml`
accordingly.

## 1. Create the Monitoring Network

```bash
dokku network:create monitoring
```

All three apps will be attached to this network so they can reach each other
by hostname without being exposed publicly.

## 2. Deploy dokku-radar

```bash
export DOKKU_APP=dokku-radar

dokku apps:create $DOKKU_APP
dokku storage:mount $DOKKU_APP /var/run/docker.sock:/var/run/docker.sock
dokku storage:mount $DOKKU_APP /var/lib/dokku/data:/var/lib/dokku/data:ro
dokku storage:mount $DOKKU_APP /home/dokku:/home/dokku:ro
dokku network:set $DOKKU_APP attach-post-deploy monitoring
dokku proxy:disable $DOKKU_APP
dokku git:from-image $DOKKU_APP ghcr.io/joeyates/dokku-radar:latest
```

The exporter is never exposed publicly — `proxy:disable` ensures no domains
are assigned and no external port mapping is created.

## 3. Deploy Prometheus

```bash
export DOKKU_APP=prometheus

dokku apps:create $DOKKU_APP
```

### Storage and Configuration

Create the storage directory and subdirectories for config and data:

```bash
dokku storage:ensure-directory $DOKKU_APP
ssh root@$DOKKU_HOST "mkdir -p /var/lib/dokku/data/storage/$DOKKU_APP/{config,data}"
```

Copy the Prometheus configuration to the host:

```bash
scp prometheus/prometheus.yml root@$DOKKU_HOST:/var/lib/dokku/data/storage/$DOKKU_APP/config/prometheus.yml
```

Mount the config file and data directory:

```bash
dokku storage:mount $DOKKU_APP /var/lib/dokku/data/storage/$DOKKU_APP/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
dokku storage:mount $DOKKU_APP /var/lib/dokku/data/storage/$DOKKU_APP/data:/prometheus
```

Fix permissions on the data directory — the Prometheus container runs as
UID 65534 (`nobody`):

```bash
ssh root@$DOKKU_HOST "chown -R 65534:65534 /var/lib/dokku/data/storage/$DOKKU_APP/data"
```

### Network and Deploy

```bash
dokku network:set $DOKKU_APP attach-post-deploy monitoring
dokku git:from-image $DOKKU_APP quay.io/prometheus/prometheus:latest
```

### Updating Prometheus Configuration

To update `prometheus.yml` after deployment:

```bash
scp prometheus/prometheus.yml root@$DOKKU_HOST:/var/lib/dokku/data/storage/$DOKKU_APP/config/prometheus.yml
dokku ps:restart $DOKKU_APP
```

## 4. Deploy Grafana

```bash
export DOKKU_APP=grafana

dokku apps:create $DOKKU_APP
dokku storage:ensure-directory $DOKKU_APP
dokku storage:mount $DOKKU_APP /var/lib/dokku/data/storage/$DOKKU_APP:/var/lib/grafana
dokku network:set $DOKKU_APP attach-post-deploy monitoring
```

Fix permissions — the Grafana container runs as UID 472:

```bash
ssh root@$DOKKU_HOST "chown -R 472:472 /var/lib/dokku/data/storage/$DOKKU_APP"
```

Deploy:

```bash
dokku git:from-image $DOKKU_APP grafana/grafana:latest
```

### Configure the Datasource

1. Open Grafana in your browser (or set up a domain with
   `dokku domains:set grafana grafana.example.com`)
2. Go to **Connections → Data sources → Add data source**
3. Select **Prometheus**
4. Set the URL to: `http://prometheus.web.1:9090`
5. Click **Save & test** — should show "Successfully queried the Prometheus API"

### Import the Dashboard

1. Go to **Dashboards → New → Import**
2. Click **Upload JSON file**
3. Select `grafana/dashboard.json` from this repository
4. Select the Prometheus datasource you just created
5. Click **Import**

## 5. Verify the Stack

Check dokku-radar is responding (from the host, or via `dokku enter`):

```bash
# Health check
dokku run dokku-radar curl -s http://localhost:9110/health
# => ok

# Metrics endpoint
dokku run dokku-radar curl -s http://localhost:9110/metrics | head -20
```

Check Prometheus is scraping successfully:

- Open the Prometheus web UI (or via `dokku enter prometheus`)
- Go to **Status → Targets**
- The `dokku_radar` job should show state **UP**

Check Grafana:

- Open the Dokku Radar dashboard
- All panels should display data

## 6. Troubleshooting

### Docker socket permission denied

If dokku-radar logs show `permission denied` when accessing
`/var/run/docker.sock`:

```bash
# Check the socket permissions on the host
ssh root@$DOKKU_HOST "ls -la /var/run/docker.sock"
```

The socket must be readable by the container's user. Typically, adjusting
socket permissions or adding the container user to the `docker` group
resolves this.

### Prometheus cannot reach dokku-radar

If the Prometheus targets page shows dokku-radar as **DOWN**:

1. Confirm both apps are on the `monitoring` network:
   ```bash
   dokku network:report dokku-radar
   dokku network:report prometheus
   ```
2. Both should show `monitoring` under "Attach post-deploy"
3. If either is missing, set the network and redeploy:
   ```bash
   dokku network:set <app> attach-post-deploy monitoring
   dokku ps:rebuild <app>
   ```

### Grafana datasource "Bad Gateway"

If the Prometheus datasource test fails in Grafana:

1. Confirm the Prometheus app is running:
   ```bash
   dokku ps:report prometheus
   ```
2. Verify the datasource URL uses the internal network hostname:
   `http://prometheus.web.1:9090` — **not** `localhost`
3. Confirm Grafana is on the `monitoring` network:
   ```bash
   dokku network:report grafana
   ```

### Prometheus data directory permission denied

If Prometheus logs show permission errors on `/prometheus/`:

```bash
ssh root@$DOKKU_HOST "chown -R 65534:65534 /var/lib/dokku/data/storage/prometheus/data"
dokku ps:restart prometheus
```

The Prometheus container runs as UID 65534 (`nobody`).

## 7. Optional Next Steps

### Expose Grafana and Prometheus via HTTPS

For each app you want to expose publicly, set the domain, configure the port
mapping, and enable Let's Encrypt. Set `DOKKU_APP`, `APP_DOMAIN`, `APP_PORT`,
and `DOMAIN_EMAIL` for each app.

**Grafana** (default port 3000):

```bash
export DOKKU_APP=grafana
export APP_DOMAIN=grafana.example.com
export APP_PORT=3000
export DOMAIN_EMAIL=you@example.com

dokku domains:set $DOKKU_APP $APP_DOMAIN
dokku ports:set $DOKKU_APP http:80:$APP_PORT
dokku letsencrypt:set $DOKKU_APP email $DOMAIN_EMAIL
dokku letsencrypt:enable $DOKKU_APP
```

**Prometheus** (default port 9090):

```bash
export DOKKU_APP=prometheus
export APP_DOMAIN=prometheus.example.com
export APP_PORT=9090
export DOMAIN_EMAIL=you@example.com

dokku domains:set $DOKKU_APP $APP_DOMAIN
dokku ports:set $DOKKU_APP http:80:$APP_PORT
dokku letsencrypt:set $DOKKU_APP email $DOMAIN_EMAIL
dokku letsencrypt:enable $DOKKU_APP
```

### Add node_exporter for Host-level Metrics

Deploy [node_exporter](https://github.com/prometheus/node_exporter) as
another Dokku app on the `monitoring` network, then uncomment the
`node_exporter` job in `prometheus.yml`.

## 8. Troubleshooting

### Prometheus fails to start: "lock DB directory: resource temporarily unavailable"

If Prometheus fails to restart with this error, the previous container didn't
release its lock file. Stop the app, remove the lock, and start again:

```bash
dokku ps:stop prometheus
dokku-root rm /var/lib/dokku/data/storage/prometheus/data/lock
dokku ps:start prometheus
```

### Verifying dokku-radar metrics from the monitoring network

To check if Prometheus can reach dokku-radar without logging into the server:

```bash
ssh root@$DOKKU_HOST docker exec prometheus.web.1 wget -qO- http://dokku-radar.web.1:9110/metrics
```

## 9. Limitations

Dokku Radar confirms containers are running but **cannot verify that apps are
responding correctly to HTTP requests**. A container may be in `running` state
but returning errors or timing out.

For HTTP availability monitoring, consider deploying
[blackbox_exporter](https://github.com/prometheus/blackbox_exporter) as an
additional monitoring app to probe your app domains. This is outside the
scope of this project.
