#!/usr/bin/env bash
# Runs the steps in curl/ in order. Safe to re-run: existing items are skipped.
set -euo pipefail
. "$(dirname "$0")/../env.sh"
C="$ROOT/curl"

"$C/00-wait.sh"
"$C/01-admin-password.sh"
"$C/02-docker-realm.sh"
for f in 10-pypi-proxy 11-pypi-hosted 12-pypi-group 20-docker-proxy 21-docker-hosted 22-docker-group; do
  "$C/$f.sh"
done
if [ "${ANONYMOUS:-true}" = true ]; then "$C/30-anonymous.sh" on; else "$C/30-anonymous.sh" off; fi

echo
echo "pip index-url: $NEXUS_URL/repository/pypi-all/simple"
echo "docker mirror: $NEXUS_URL"
