# Sourced by the helper scripts. Reads .env from the project root.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
[ -f .env ] && . ./.env

NEXUS_URL=${NEXUS_URL:-https://nexus.example.com}
HOST=${NEXUS_URL#*://}; HOST=${HOST%%[:/]*}
ENGINE=${ENGINE:-docker}                # docker or podman
COMPOSE=${COMPOSE:-docker compose}      # "docker compose" or "podman-compose"
PASS=${NEW_ADMIN_PASSWORD:-}
KEY=secrets/nexus-secrets.json

# Talk to Caddy on this machine, but keep normal certificate checks.
curl() {
  local a=(--resolve "$HOST:443:127.0.0.1")
  [ -n "${CA_CERT:-}" ] && a+=(--cacert "$CA_CERT")
  command curl "${a[@]}" "$@"
}
