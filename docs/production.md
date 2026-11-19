# Production notes

## What is already hardened

| Area | Setting |
|---|---|
| Versions | Nexus and Caddy pinned; compose and `preflight.sh` reject `latest` |
| Exposure | only Caddy publishes 80/443; Nexus ports exist on the internal network only |
| TLS | your certificate, HSTS, HTTP redirects to HTTPS, `Server` header removed |
| Containers | `no-new-privileges` on both |
| Shutdown | Nexus gets 120 s to stop cleanly |
| Logs | Caddy access log to stdout; set log rotation on the engine (below) |
| Secrets | Nexus stored secrets encrypted with your own key; `.env` and `tls.key` must be mode 600 |
| Data | named volume, scheduled backups with retention |
| Config checks | `preflight.sh` before every start or upgrade |

## Log rotation

Docker: add to `/etc/docker/daemon.json` and restart Docker:

```json
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "5" } }
```

Podman: set `log_size_max` in `containers.conf` (for example `log_size_max = 10485760`).

## Go-live checklist

- [ ] DNS name resolves to the server; the name is in the certificate
- [ ] `./scripts/server/preflight.sh` passes
- [ ] `NEW_ADMIN_PASSWORD` is long and unique; remove it from `.env` after `setup.sh` succeeds and store it in your password manager (it is only needed again to re-run the scripts)
- [ ] `secrets/nexus-secrets.json` copied off the server
- [ ] Anonymous access decided: `ANONYMOUS=true` is read-only; for stricter control turn it off and give clients a read-only user
- [ ] Firewall allows 80 and 443 from client networks only; the server can reach pypi.org, files.pythonhosted.org and the Docker Hub hosts (docs/server.md)
- [ ] Certificate files owned by the user running the containers, key mode 600
- [ ] Docker Hub token set if many hosts pull
- [ ] Backup cron installed and a restore tested
- [ ] Cleanup policies on `docker-proxy` and `pypi-proxy`
- [ ] Containers start after a reboot (Docker enabled at boot; Podman: `loginctl enable-linger` and `podman-restart.service`), reboot test done
- [ ] Certificate renewal date in a calendar

## Deliberately left out

Kept simple on purpose. Add these if your environment needs them:

- High availability or an external database (single node, one volume)
- LDAP/SSO (Nexus supports it in the UI: Security > LDAP; FreeIPA works)
- Metrics and alerting (Nexus exposes `/service/metrics/prometheus` to authenticated users)
- Firewall rules and host hardening (managed outside this project)
