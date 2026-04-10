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

### SSH Key Setup for Service Metrics

dokku-radar queries installed Dokku service plugins (postgres, redis, etc.) via
SSH to expose `dokku_service_linked` and `dokku_service_status` metrics. This
requires a dedicated SSH keypair with access to the `dokku` user on the host.

**1. Generate a dedicated keypair** on your local machine:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/dokku-radar -N "" -C "dokku-radar"
```

**2. Authorise the public key** on the Dokku host:

```bash
cat ~/.ssh/dokku-radar.pub | ssh root@$DOKKU_HOST "cat >> /home/dokku/.ssh/authorized_keys"
```

Verify the key works:

```bash
ssh -i ~/.ssh/dokku-radar dokku@$DOKKU_HOST plugin:list
```

**3. Store the private key** in Dokku's storage directory:

```bash
ssh root@$DOKKU_HOST "mkdir -p /var/lib/dokku/data/storage/dokku-radar/.ssh"
scp ~/.ssh/dokku-radar root@$DOKKU_HOST:/var/lib/dokku/data/storage/dokku-radar/.ssh/id_ed25519
ssh root@$DOKKU_HOST "chmod 600 /var/lib/dokku/data/storage/dokku-radar/.ssh/id_ed25519"
```

**4. Mount the SSH directory** into the container:

```bash
dokku storage:mount dokku-radar /var/lib/dokku/data/storage/dokku-radar/.ssh:/root/.ssh:ro
```

**5. Set the Dokku host** environment variable so dokku-radar can find the
host to SSH into:

```bash
dokku config:set dokku-radar DOKKU_HOST=$DOKKU_HOST
```

Restart the app to apply:

```bash
dokku ps:restart dokku-radar
```

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
export APP_DOMAIN=grafana.example.com
export APP_PORT=3000
export DOMAIN_EMAIL=you@example.com

dokku apps:create $DOKKU_APP
dokku domains:set $DOKKU_APP $APP_DOMAIN
```

### Expose via HTTPS

```bash
dokku ports:set $DOKKU_APP http:80:$APP_PORT
dokku letsencrypt:set $DOKKU_APP email $DOMAIN_EMAIL
dokku letsencrypt:enable $DOKKU_APP
```

### Set Up Storage

```bash
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

## Next Steps

- See [system-checks.md](system-checks.md) to verify the stack is working correctly.
- See [troubleshooting.md](troubleshooting.md) if you encounter issues.
