# Nexus proxy for Python and Docker

A caching proxy for **PyPI** and **Docker Hub** using Sonatype Nexus Repository behind Caddy (HTTPS with your own certificate). The first request downloads from the internet once; every later request is served from your network.

```
client (pip / docker)  --443-->  Caddy (TLS)  -->  Nexus
                                    /v2/*   -->  :5000  docker-all  -> docker-proxy -> Docker Hub
                                    others  -->  :8081  pypi-all    -> pypi-proxy   -> pypi.org
```

Only Caddy is published (80/443). Nexus is reachable by Caddy on the compose network only. Works with Docker or rootless Podman.

| Repository | Type | Purpose |
|---|---|---|
| `pypi-proxy` / `pypi-hosted` / `pypi-all` | proxy / hosted / group | cache of pypi.org / your packages / what pip uses |
| `docker-proxy` / `docker-hosted` / `docker-all` | proxy / hosted / group | cache of Docker Hub / your images / what clients use |

Examples use `nexus.example.com` and `192.0.2.10`. Replace them with your own.

## Pinned versions

Nothing runs on `latest`. Versions live in `.env`, and `compose.yaml` refuses to start if they are missing.

| Component | Pin | Where |
|---|---|---|
| Nexus | `3.98.2` (example default) | `NEXUS_TAG` |
| Caddy | `2.11.7` | `CADDY_TAG` |
| Helper image | `alpine:3.20` | `scripts/server/backup.sh` |

Upgrading is an edit of the tag: [docs/operations.md](docs/operations.md).

## Quick start

```bash
# 1. Configuration (set NEXUS_URL, SITE_ADDRESSES, NEW_ADMIN_PASSWORD; for Podman also ENGINE and COMPOSE)
cp .env.example .env && chmod 600 .env
vi .env

# 2. Your certificate (full chain + key)
cp /path/fullchain.pem certs/tls.crt
cp /path/privkey.pem   certs/tls.key
chmod 600 certs/tls.key

# 3. Secret encryption key for Nexus (before the first start)
./scripts/server/secrets.sh init

# 4. Check configuration: pinned tags, certificate, key, names
./scripts/server/preflight.sh

# 5. Start (Nexus needs 1-3 minutes)
docker compose up -d            # Podman: podman-compose up -d

# 6. Create the repositories and set the admin password (runs the steps in curl/)
./scripts/server/setup.sh

# 7. Check
./scripts/server/status.sh
```

## Use the proxy

- **Docker** (mirror, explicit pulls, Dockerfile and compose samples): [examples/docker/](examples/docker/README.md)
- **pip**: set `index-url = https://nexus.example.com/repository/pypi-all/simple` in `pip.conf`, and pin every package as `name==x.y.z`.

## Layout

```
compose.yaml  Caddyfile  .env.example
certs/                 your tls.crt and tls.key (git-ignored)
secrets/               generated Nexus key (git-ignored)
curl/                  one curl script per Nexus API step (README inside)
scripts/server/        preflight, secrets, setup, status, backup
examples/docker/       client samples: daemon.json, Podman, RKE2, Dockerfile, compose
docs/                  server, operations, production, troubleshooting
```

## Docs

- [docs/server.md](docs/server.md) install, certificate, start, Podman notes
- [curl/README.md](curl/README.md) the API commands, step by step
- [examples/docker/README.md](examples/docker/README.md) using the Docker proxy
- [docs/operations.md](docs/operations.md) anonymous access, upgrade, backup, certificate renewal, cleanup
- [docs/production.md](docs/production.md) what is hardened and the go-live checklist
- [docs/troubleshooting.md](docs/troubleshooting.md) errors and fixes
