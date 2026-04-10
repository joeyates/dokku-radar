# System Checks

## Check dokku-radar

Check dokku-radar is running:

```bash
dokku ps:report dokku-radar
```

This should include `Running: true`

Check the logs:

```bash
dokku logs dokku-radar
```

Check dokku-radar's endpoint is running:

```bash
# Health check
dokku enter dokku-radar web wget -qO- http://127.0.0.1:9110/health
# => ok

# Metrics endpoint
dokku enter dokku-radar web wget -qO- http://127.0.0.1:9110/metrics | head -20
```

Check dokku-radar has access to the host's dokku:

```bash
ssh -t dokku@$DOKKU_HOST enter dokku-radar web '/bin/sh -c "ssh -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o Stric
tHostKeyChecking=no dokku@$DOKKU_HOST plugin:list"'
```

### Check Prometheus

```bash
dokku enter prometheus web wget -qO- 'http://127.0.0.1:9090/api/v1/targets?state=unhealthy' | jq .
```

In activeTargets there should be `"job": "dokku_radar"` and `"health": "up"`.

### Check Grafana

Run the previous API all from the Grafana container:

```bash
dokku enter grafana web wget -qO- http://prometheus.web.1:9090/api/v1/targets | jq .
```

- Open the Dokku Radar dashboard
- All panels should display data

See [next-steps.md](next-steps.md) for optional extensions to the monitoring stack.
