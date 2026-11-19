#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../env.sh"

: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
IMAGE=${1:?usage: image-role.sh <image-path, for example library/nginx>}
NAME=docker-$(echo "$IMAGE" | tr '/.:_' '----')
API="$NEXUS/service/rest/v1/security"

EXPR="format == \"docker\" and path =^ \"/v2/$IMAGE/\""

post() {
  curl -fsS -u "admin:$PASS" -X POST "$API/$1" -H 'Content-Type: application/json' -d "$2"
}

SELECTOR=$(python3 - "$NAME" "$IMAGE" "$EXPR" <<'PY'
import json, sys
print(json.dumps({"name": sys.argv[1], "description": "docker image " + sys.argv[2], "expression": sys.argv[3]}))
PY
)

PRIV=$(python3 - "$NAME" "$IMAGE" <<'PY'
import json, sys
print(json.dumps({
    "name": sys.argv[1] + "-read",
    "description": "pull docker image " + sys.argv[2],
    "actions": ["BROWSE", "READ"],
    "format": "docker",
    "repository": "docker-all",
    "contentSelector": sys.argv[1],
}))
PY
)

ROLE=$(python3 - "$NAME" "$IMAGE" <<'PY'
import json, sys
print(json.dumps({
    "id": "pull-" + sys.argv[1],
    "name": "pull-" + sys.argv[1],
    "description": "docker pull of " + sys.argv[2] + " only",
    "privileges": [sys.argv[1] + "-read"],
    "roles": [],
}))
PY
)

post content-selectors "$SELECTOR"
post privileges/repository-content-selector "$PRIV"
post roles "$ROLE"
echo "role: pull-$NAME (selector: $EXPR)"