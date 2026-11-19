# Operations

Use `podman-compose` and `podman` instead of `docker compose` and `docker` if you run Podman.

## Day to day

```bash
docker compose ps
docker compose logs -f --tail 100 nexus
docker compose logs -f --tail 100 caddy
docker compose restart nexus
docker compose down                 # keeps the data volume
./scripts/server/status.sh
```

## Anonymous access

```bash
./curl/30-anonymous.sh status
./curl/30-anonymous.sh on      # pip and docker need no login
./curl/30-anonymous.sh off     # create a read-only user in the UI first
```

After turning it off, clients need credentials: for pip put them in the index URL (`https://user:password@nexus.example.com/repository/pypi-all/simple`, URL-encode special characters), for Docker run `docker login nexus.example.com`.

## Upgrade (pinned)

Nexus upgrades only forward, so back up first and read the release notes of the target version. Never switch to `latest`.

```bash
./scripts/server/backup.sh
vi .env                                  # NEXUS_TAG=<new version>
docker compose pull
docker compose up -d
./scripts/server/status.sh
```

Same for Caddy with `CADDY_TAG`. To roll back, restore the backup and the previous tag.

## Backup and restore

```bash
./scripts/server/backup.sh               # stops Nexus briefly, writes backups/nexus-data-<date>.tar.gz
```

Backups older than `KEEP_DAYS` (default 14) are deleted. Also copy `backups/`, `secrets/nexus-secrets.json` and `.env` to another machine.

Schedule it (Nexus is stopped for a minute or two, so pick a quiet hour):

```bash
sudo tee /etc/cron.d/nexus-backup <<'CRON'
30 2 * * * root cd /opt/nexus-proxy && ./scripts/server/backup.sh >> /var/log/nexus-backup.log 2>&1
CRON
```

Test a restore at least once.

Restore into an empty volume:

```bash
docker compose down
docker volume rm nexus-data
docker volume create nexus-data
docker run --rm -v nexus-data:/data -v "$PWD/backups:/backup" docker.io/library/alpine:3.20 \
  tar xzf /backup/nexus-data-<date>.tar.gz -C /data
docker compose up -d
```

## Renew the certificate

```bash
cp /path/new-fullchain.pem certs/tls.crt
cp /path/new-privkey.pem   certs/tls.key && chmod 600 certs/tls.key
./scripts/server/preflight.sh
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

No downtime. `preflight.sh` warns when less than 30 days remain; run it from cron if you want an early reminder.

## Disk cleanup

Docker images are large. In the UI, Settings > Repository > Cleanup Policies, add a policy (for example remove components not downloaded for 60 days) to `docker-proxy` and `pypi-proxy`, then run the task `Admin - Compact blob store`.

## Reuse an existing Nexus data volume

```bash
docker inspect nexus --format '{{range .Mounts}}{{.Name}} {{.Destination}}{{"\n"}}{{end}}'
docker compose down
# set NEXUS_VOLUME=<volume-name> and the current NEW_ADMIN_PASSWORD in .env
docker compose up -d
./scripts/server/secrets.sh encrypt      # re-encrypt old secrets with the custom key
./scripts/server/setup.sh                # adds any missing repository
```
