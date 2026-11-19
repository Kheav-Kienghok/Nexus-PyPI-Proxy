# curl: Nexus API commands

One script per step. Each is a plain `curl` call to the Nexus REST API (`/service/rest/v1`), safe to re-run, and runs on its own. `scripts/server/setup.sh` runs them all in this order.

| Script | What it does |
|---|---|
| `00-wait.sh` | waits until Nexus answers |
| `01-admin-password.sh` | replaces the generated admin password with `NEW_ADMIN_PASSWORD` |
| `02-docker-realm.sh` | enables the Docker Bearer Token realm (needed for Docker clients) |
| `10-pypi-proxy.sh` | `pypi-proxy`: cache of pypi.org |
| `11-pypi-hosted.sh` | `pypi-hosted`: your own packages |
| `12-pypi-group.sh` | `pypi-all`: what pip uses (hosted first, then proxy) |
| `20-docker-proxy.sh` | `docker-proxy`: cache of Docker Hub (uses `DOCKERHUB_USER` / `DOCKERHUB_TOKEN` if set) |
| `21-docker-hosted.sh` | `docker-hosted`: your own images |
| `22-docker-group.sh` | `docker-all`: what Docker clients use |
| `30-anonymous.sh on\|off\|status` | anonymous read access |
| `40-list-repos.sh` | lists repositories |

```bash
./curl/10-pypi-proxy.sh            # run one step
./curl/30-anonymous.sh status
```

`_env.sh` loads `.env` and defines the helpers `create` and `exists`. It calls Nexus through Caddy on this machine (`--resolve <name>:443:127.0.0.1`) with normal certificate checks.

## Without the scripts

The same call by hand, creating `pypi-proxy`:

```bash
curl -fsS -u admin:'<password>' -X POST \
  https://nexus.example.com/service/rest/v1/repositories/pypi/proxy \
  -H 'Content-Type: application/json' -d '{
  "name": "pypi-proxy", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "proxy": {"remoteUrl": "https://pypi.org", "contentMaxAge": 1440, "metadataMaxAge": 1440},
  "negativeCache": {"enabled": true, "timeToLive": 1440},
  "httpClient": {"blocked": false, "autoBlock": true}}'
```

Other useful calls:

```bash
# health and repositories
curl -fsS -u admin:'<password>' https://nexus.example.com/service/rest/v1/status/check
curl -fsS -u admin:'<password>' https://nexus.example.com/service/rest/v1/repositories

# delete a repository
curl -fsS -u admin:'<password>' -X DELETE https://nexus.example.com/service/rest/v1/repositories/pypi-proxy
```
