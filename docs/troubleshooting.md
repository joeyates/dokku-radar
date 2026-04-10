# Troubleshooting

## Docker Socket Permission Denied

If dokku-radar logs show `permission denied` when accessing
`/var/run/docker.sock`:

```bash
# Check the socket permissions on the host
ssh root@$DOKKU_HOST "ls -la /var/run/docker.sock"
```

The socket must be readable by the container's user. Typically, adjusting
socket permissions or adding the container user to the `docker` group
resolves this.

## Prometheus Cannot Reach dokku-radar

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

## Grafana Datasource "Bad Gateway"

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

## Prometheus Data Directory Permission Denied

If Prometheus logs show permission errors on `/prometheus/`:

```bash
ssh root@$DOKKU_HOST "chown -R 65534:65534 /var/lib/dokku/data/storage/prometheus/data"
dokku ps:restart prometheus
```

The Prometheus container runs as UID 65534 (`nobody`).

## Prometheus Fails to Start: "lock DB directory: resource temporarily unavailable"

If Prometheus fails to restart with this error, the previous container didn't
release its lock file. Stop the app, remove the lock, and start again:

```bash
dokku ps:stop prometheus
dokku-root rm /var/lib/dokku/data/storage/prometheus/data/lock
dokku ps:start prometheus
```
