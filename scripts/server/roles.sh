#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../env.sh"

: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
API="$NEXUS/service/rest/v1/security"

role() {
  if curl -fsS -u "admin:$PASS" "$API/roles" | grep -Eq "\"id\" *: *\"$1\""; then
    echo "skip role $1"
  else
    curl -fsS -u "admin:$PASS" -X POST "$API/roles" -H 'Content-Type: application/json' -d "$2"
    echo "created role $1"
  fi
}

role pypi-reader '{
  "id": "pypi-reader",
  "name": "pypi-reader",
  "description": "pip install from pypi-all",
  "privileges": [
    "nx-repository-view-pypi-pypi-all-browse",
    "nx-repository-view-pypi-pypi-all-read"
  ],
  "roles": []
}'

role pypi-publisher '{
  "id": "pypi-publisher",
  "name": "pypi-publisher",
  "description": "pip install from pypi-all and upload to pypi-hosted",
  "privileges": [
    "nx-repository-view-pypi-pypi-all-browse",
    "nx-repository-view-pypi-pypi-all-read",
    "nx-repository-view-pypi-pypi-hosted-browse",
    "nx-repository-view-pypi-pypi-hosted-read",
    "nx-repository-view-pypi-pypi-hosted-add"
  ],
  "roles": []
}'

role docker-puller '{
  "id": "docker-puller",
  "name": "docker-puller",
  "description": "docker pull from docker-all",
  "privileges": [
    "nx-repository-view-docker-docker-all-browse",
    "nx-repository-view-docker-docker-all-read"
  ],
  "roles": []
}'

role docker-pusher '{
  "id": "docker-pusher",
  "name": "docker-pusher",
  "description": "docker pull from docker-all and push to docker-hosted",
  "privileges": [
    "nx-repository-view-docker-docker-all-browse",
    "nx-repository-view-docker-docker-all-read",
    "nx-repository-view-docker-docker-hosted-browse",
    "nx-repository-view-docker-docker-hosted-read",
    "nx-repository-view-docker-docker-hosted-add",
    "nx-repository-view-docker-docker-hosted-edit"
  ],
  "roles": []
}'