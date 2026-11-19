# Server setup

Run on the Nexus host. Requirements: Docker Engine with the compose plugin, **or** rootless Podman with `podman-compose`; plus `curl`, `openssl`, `python3`, 4 GB RAM or more, and 100 GB or more of disk for Docker images.

## 1. Configure

```bash
cp .env.example .env
chmod 600 .env          # holds passwords
vi .env
```

| Variable | Example | Meaning |
|---|---|---|
| `NEXUS_URL` | `https://nexus.example.com` | address clients use |
| `SITE_ADDRESSES` | `'nexus.example.com, 192.0.2.10'` | names Caddy serves; your certificate must cover them |
| `NEXUS_TAG` | `3.98.2` | pinned Nexus version |
| `CADDY_TAG` | `2.11.7` | pinned Caddy version |
| `NEW_ADMIN_PASSWORD` | `'change-me'` | admin password set by `setup.sh` |
| `ANONYMOUS` | `true` | read access without login |
| `NEXUS_HEAP`, `NEXUS_DIRECT_MEM` | `2g`, `3g` | JVM memory |
| `DOCKERHUB_USER`, `DOCKERHUB_TOKEN` | | optional, raises the Docker Hub pull limit |
| `ENGINE`, `COMPOSE` | `docker`, `'docker compose'` | engine for the helper scripts; Podman: `podman`, `podman-compose` |

## 2. Certificate

Copy your own certificate. `tls.crt` must contain the full chain (your certificate first, then the intermediates).

```bash
cp /path/fullchain.pem certs/tls.crt
cp /path/privkey.pem   certs/tls.key
chmod 600 certs/tls.key
```

Files must be owned by the user who runs the containers (`chown $USER:$USER certs/*`); with rootless Podman a key owned by root is unreadable.

## 3. Encryption key

```bash
./scripts/server/secrets.sh init
```

Creates `secrets/nexus-secrets.json`, used by Nexus to encrypt stored secrets. **Create it before the first start**: if the file is missing, compose creates a *directory* of that name and Nexus restarts in a loop. **Back it up outside the server**; without it a restored backup cannot decrypt them.

## 4. Preflight

```bash
./scripts/server/preflight.sh
```

Fails on an unpinned tag, a missing key (or a key that is a directory), a certificate that does not match the key, has expired or soon will, or does not cover a name in `SITE_ADDRESSES`.

## 5. Start

```bash
docker compose up -d              # Podman: podman-compose up -d
docker compose logs -f nexus      # Podman: podman exec nexus tail -f /nexus-data/log/nexus.log
```

Nexus needs 1-3 minutes. Do not run `down`/`up` again while waiting: every restart restarts the clock.

## 6. Create the repositories

```bash
./scripts/server/setup.sh
```

It runs the scripts in [curl/](../curl/README.md) in order: wait for Nexus, change the admin password to `NEW_ADMIN_PASSWORD`, enable the Docker Bearer Token realm, create the six repositories, apply `ANONYMOUS`. It is safe to run again. Each step is also a plain `curl` call you can run alone.

## 7. Check

```bash
./scripts/server/status.sh           # containers, endpoints, repositories, health
./scripts/server/status.sh repos
./scripts/server/status.sh health
```

`/v2/` answering `200` or `401` means the Docker registry is reachable through Caddy.

## Podman notes

- In `.env`: `ENGINE=podman` and `COMPOSE=podman-compose`.
- Rootless Podman cannot bind ports 80 and 443 by default:

  ```bash
  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
  echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf
  ```

- Keep containers running after logout and start them after a reboot:

  ```bash
  sudo loginctl enable-linger $USER
  systemctl --user enable podman-restart.service
  ```

- The `:Z` flags on the volumes in `compose.yaml` are for SELinux and are harmless elsewhere.
- Caddy connects to Nexus as `nexus-app`, not `nexus`. Podman copies the host's `/etc/hosts` into containers, so on a server whose hostname is `nexus` the name `nexus` resolves to `127.0.1.1` and Caddy answers 502. The alias avoids it.

## DNS

Point your name at the server, for example with FreeIPA:

```bash
ipa dnsrecord-add example.com nexus --a-rec 192.0.2.10
```

## Network

| From | To | Port |
|---|---|---|
| clients | Caddy | 443 (80 redirects to 443) |
| Nexus | pypi.org, files.pythonhosted.org | 443 |
| Nexus | registry-1.docker.io, auth.docker.io, production.cloudflare.docker.com | 443 |

## Cache timing

`contentMaxAge` and `metadataMaxAge` are 1440 minutes. Package files never change after release; lower the metadata age if new releases must appear sooner.
