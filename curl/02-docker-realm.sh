#!/usr/bin/env bash
# Docker clients need the Docker Bearer Token realm (anonymous pulls too).
set -euo pipefail
. "$(dirname "$0")/_env.sh"

REALMS=$(curl -fsS "${AUTH[@]}" "$API/security/realms/active")
if echo "$REALMS" | grep -q DockerToken; then
  echo "skip docker token realm (enabled)"
else
  curl -fsS "${AUTH[@]}" -X PUT "$API/security/realms/active" "${JSON[@]}" \
    -d "$(echo "$REALMS" | python3 -c 'import json,sys; r=json.load(sys.stdin); r.append("DockerToken"); print(json.dumps(r))')"
  echo "enabled docker token realm"
fi
