#!/usr/bin/env bash
# usage: status.sh [all|repos|health]
set -euo pipefail
. "$(dirname "$0")/../env.sh"
: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
API="$NEXUS_URL/service/rest/v1"

repos() {
  curl -fsS -u "admin:$PASS" "$API/repositories" | python3 -c '
import json, sys
for r in json.load(sys.stdin):
    print("%-14s %-8s %s" % (r["name"], r["type"], r["format"]))'
}
health() {
  curl -sS -u "admin:$PASS" "$API/status/check" | python3 -c '
import json, sys
for k, v in sorted(json.load(sys.stdin).items()):
    print("%-10s %s" % ("OK" if v.get("healthy") else "UNHEALTHY", k))'
}

case "${1:-all}" in
  repos) repos ;;
  health) health ;;
  all)
    echo "== containers"
    "$ENGINE" ps -a --filter name=nexus --filter name=caddy --format '{{.Names}}  {{.Status}}'
    echo "== endpoints"
    for u in /service/rest/v1/status /repository/pypi-all/simple/ /v2/; do
      curl -sS -o /dev/null -w "$u -> HTTP %{http_code}\n" "$NEXUS_URL$u"
    done
    echo "== repositories"; repos
    echo "== health"; health
    ;;
  *) echo "usage: $0 [all|repos|health]"; exit 1 ;;
esac
