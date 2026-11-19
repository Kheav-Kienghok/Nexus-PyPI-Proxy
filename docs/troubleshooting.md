# Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Compose says `set NEXUS_TAG in .env` | Versions are required on purpose. Copy them from `.env.example`. |
| Nexus restarts in a loop, `ls -l secrets/` shows `nexus-secrets.json` as a **directory** | Compose started before the key existed and created a directory. `docker compose down`, `rmdir secrets/nexus-secrets.json`, `./scripts/server/secrets.sh init`, start again. |
| `setup.sh` waits forever | Nexus is still starting (1-3 min after the last start) or crashed. Docker: `docker compose logs nexus`. Podman: `podman exec nexus tail -n 40 /nexus-data/log/nexus.log`. Check RAM against `NEXUS_HEAP`. |
| Caddy returns 502 but Nexus works inside its container | Caddy cannot reach the upstream. Check `podman exec caddy wget -S -qO /dev/null http://nexus-app:8081/service/rest/v1/status`. If the name resolves to `127.0.1.1`, the Caddyfile still points at `nexus` instead of `nexus-app` (see docs/server.md, Podman notes). Restart Caddy after editing the Caddyfile. |
| `admin login failed` | `NEW_ADMIN_PASSWORD` in `.env` is not the current admin password. |
| Nexus fails with a secrets key error | `secrets/nexus-secrets.json` is missing, unreadable (needs mode 444) or has the wrong content. On a restored install use the original key. |
| Caddy cannot read the certificate or key | Files must be owned by the user running the containers: `sudo chown $USER:$USER certs/*; chmod 600 certs/tls.key`. |
| pip: `CERTIFICATE_VERIFY_FAILED` | Chain incomplete (use the full chain in `certs/tls.crt`), name not in the certificate, or internal CA not trusted on the client. |
| pip: `404` for a package | Name typo, or that version does not exist on pypi.org. Open `https://nexus.example.com/repository/pypi-all/simple/<name>/`. |
| pip: `externally-managed-environment` | Use a venv: `python3 -m venv venv && . venv/bin/activate`. |
| pip: `401` | Anonymous access is off; put credentials in the index URL. |
| docker: `x509: certificate signed by unknown authority` | Internal CA not installed on the client (examples/docker/README.md). |
| docker: `/v2/` returns 404 | Docker connector missing. Re-run `setup.sh` and check `docker-all` has HTTP port 5000. |
| Second pull is not faster | Daemon is not using the mirror, or the image is from another registry. `docker info` lists `Registry Mirrors`. |
| `toomanyrequests` from Docker Hub | Set `DOCKERHUB_USER` and `DOCKERHUB_TOKEN` (examples/docker/README.md). |
| Cannot bind 80/443 | Rootless Podman: see docs/server.md. Otherwise another service uses the port: `sudo ss -ltnp 'sport = :443'`. |
| Containers gone after logout or reboot (Podman) | `sudo loginctl enable-linger $USER` and `systemctl --user enable podman-restart.service`. |
| `preflight.sh` fails | Each FAIL line names the fix. |
