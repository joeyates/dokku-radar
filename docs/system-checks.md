# System Checks

## Verify the Stack

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

## Verifying dokku-radar Metrics from the Monitoring Network

To check if Prometheus can reach dokku-radar without logging into the server:

```bash
ssh root@$DOKKU_HOST docker exec prometheus.web.1 wget -qO- http://dokku-radar.web.1:9110/metrics
```

See [next-steps.md](next-steps.md) for optional extensions to the monitoring stack.
