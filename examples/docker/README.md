# Using the Docker proxy

Nexus caches Docker Hub (`docker.io`). The first pull of an image downloads it from Docker Hub through Nexus; every later pull comes from your server.

`nexus.example.com` is an example. Use your own name from `NEXUS_URL`.

## Two ways to pull

**1. Mirror (transparent).** Configure the client once, then normal commands go through Nexus:

```bash
docker pull nginx:1.27.3          # tries Nexus first, falls back to Docker Hub if Nexus is down
```

**2. Explicit.** Put the Nexus name in the image reference. Official images need `library/`:

```bash
docker pull nexus.example.com/library/nginx:1.27.3
docker pull nexus.example.com/grafana/grafana:11.3.0     # non-official: user/image
```

Use explicit names in a `Dockerfile` or compose file when you want the build to fail instead of silently going to the internet. See `Dockerfile` and `compose.yaml` in this folder.

## Client configuration samples

| Client | File in this folder | Install as |
|---|---|---|
| Docker | `daemon.json` | `/etc/docker/daemon.json` (merge with existing keys), then `sudo systemctl restart docker` |
| Podman | `podman-registries.conf` | `/etc/containers/registries.conf.d/nexus.conf` |
| RKE2 / containerd | `rke2-registries.yaml` | `/etc/rancher/rke2/registries.yaml` on every node |

Restarting Docker stops running containers unless `live-restore` is enabled. Plan a maintenance window.

If your certificate is signed by an internal CA that the client does not trust, install the CA first (Debian/Ubuntu):

```bash
sudo cp internal-ca.crt /usr/local/share/ca-certificates/internal-ca.crt
sudo update-ca-certificates
```

## Check that the cache works

Pull the same image twice. The second pull should be much faster:

```bash
for i in 1 2; do
  docker rmi nexus.example.com/library/alpine:3.20 >/dev/null 2>&1
  /usr/bin/time -f "pull $i: %es" docker pull nexus.example.com/library/alpine:3.20 >/dev/null
done
```

On the Nexus server, list what is cached:

```bash
./curl/40-list-repos.sh
curl -fsS -u admin:'<password>' \
  "https://nexus.example.com/service/rest/v1/components?repository=docker-proxy" | grep '"name"'
```

## Pin image versions

Use an explicit tag, ideally with the digest:

```text
nginx:1.27.3                    tag
nginx:1.27.3@sha256:<digest>    tag + digest (immutable)
```

Not `nginx` or `nginx:latest`. Get the digest after a pull:

```bash
docker inspect --format '{{index .RepoDigests 0}}' nexus.example.com/library/nginx:1.27.3
```

## Limits

- Only Docker Hub (`docker.io`) is mirrored. Images from `ghcr.io`, `quay.io` and `registry.k8s.io` are not cached; add one proxy repository per registry if you need them.
- Docker Hub limits anonymous pulls per IP, and cache misses count. Set `DOCKERHUB_USER` and `DOCKERHUB_TOKEN` in `.env` (a read-only access token) before running `setup.sh`. If `docker-proxy` already exists, set them in the UI: Settings > Repositories > `docker-proxy` > HTTP > Authentication.
- Pushing your own images goes to `docker-hosted` (connector port 5002), which Caddy does not expose. Add a Caddy site or path for it if you need to push.
