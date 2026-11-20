#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../env.sh"

: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
P=${1:?usage: project.sh <project, for example speedtest>}
[[ $P =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "project must be lowercase letters, digits and dashes"; exit 1; }
API="$NEXUS/service/rest/v1/security"
PYPI_REPO=${PYPI_REPO:-pypi-all}

exists() {
  curl -fsS -u "admin:$PASS" "$API/$1" | grep -Eq "\"$2\" *: *\"$3\""
}

create() {
  if exists "$1" "$2" "$3"; then
    echo "skip $3"
  else
    curl -fsS -u "admin:$PASS" -X POST "$API/$4" -H 'Content-Type: application/json' -d "$5"
    echo "created $3"
  fi
}

role() {
  if exists roles id "$1"; then
    curl -fsS -u "admin:$PASS" -X PUT "$API/roles/$1" -H 'Content-Type: application/json' -d "$2"
    echo "updated $1"
  else
    curl -fsS -u "admin:$PASS" -X POST "$API/roles" -H 'Content-Type: application/json' -d "$2"
    echo "created $1"
  fi
}

SELECTOR=$(python3 - "$P" <<'PY'
import json, sys
p = sys.argv[1]
print(json.dumps({
    "name": "docker-" + p,
    "description": "docker images of project " + p,
    "expression": 'format == "docker" and path =^ "/v2/%s/"' % p,
}))
PY
)

PRIV_PULL=$(python3 - "$P" <<'PY'
import json, sys
p = sys.argv[1]
print(json.dumps({
    "name": "docker-%s-pull" % p,
    "description": "view and pull images of project " + p,
    "actions": ["BROWSE", "READ"],
    "format": "docker",
    "repository": "docker-all",
    "contentSelector": "docker-" + p,
}))
PY
)

PRIV_PUSH=$(python3 - "$P" <<'PY'
import json, sys
p = sys.argv[1]
print(json.dumps({
    "name": "docker-%s-push" % p,
    "description": "push images of project " + p,
    "actions": ["BROWSE", "READ", "ADD", "EDIT"],
    "format": "docker",
    "repository": "docker-hosted",
    "contentSelector": "docker-" + p,
}))
PY
)

ROLE_VIEWER=$(python3 - "$P" "$PYPI_REPO" <<'PY'
import json, sys
p, repo = sys.argv[1:3]
print(json.dumps({
    "id": p + "-viewer",
    "name": p + "-viewer",
    "description": "view and pull images of project %s, pip install from %s" % (p, repo),
    "privileges": [
        "docker-%s-pull" % p,
        "nx-repository-view-pypi-%s-browse" % repo,
        "nx-repository-view-pypi-%s-read" % repo,
    ],
    "roles": [],
}))
PY
)

ROLE_DEV=$(python3 - "$P" "$PYPI_REPO" <<'PY'
import json, sys
p, repo = sys.argv[1:3]
print(json.dumps({
    "id": p + "-developer",
    "name": p + "-developer",
    "description": "view, pull and push images of project %s, pip install from %s" % (p, repo),
    "privileges": [
        "docker-%s-pull" % p,
        "docker-%s-push" % p,
        "nx-repository-view-pypi-%s-browse" % repo,
        "nx-repository-view-pypi-%s-read" % repo,
    ],
    "roles": [],
}))
PY
)

create content-selectors name "docker-$P" content-selectors "$SELECTOR"
create privileges name "docker-$P-pull" privileges/repository-content-selector "$PRIV_PULL"
create privileges name "docker-$P-push" privileges/repository-content-selector "$PRIV_PUSH"
role "$P-viewer" "$ROLE_VIEWER"
role "$P-developer" "$ROLE_DEV"

echo "project $P: images are named $P/<image>, pip install from $PYPI_REPO"
echo "next: ./scripts/server/user.sh robot-$P $P-developer"
