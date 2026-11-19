#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../env.sh"

: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
ID=${1:?usage: user.sh <userId> <role[,role]> [email]}
ROLES=${2:?usage: user.sh <userId> <role[,role]> [email]}
EMAIL=${3:-$ID@example.com}
PW=${USER_PASSWORD:-$(openssl rand -base64 18 | tr -d '/+=')}
API="$NEXUS/service/rest/v1/security"

if curl -fsS -u "admin:$PASS" "$API/users?userId=$ID" | grep -Eq "\"userId\" *: *\"$ID\""; then
  echo "user $ID exists, not changed"
  exit 0
fi

BODY=$(python3 - "$ID" "$ROLES" "$EMAIL" "$PW" <<'PY'
import json, sys
uid, roles, email, pw = sys.argv[1:5]
print(json.dumps({
    "userId": uid,
    "firstName": uid,
    "lastName": "service",
    "emailAddress": email,
    "password": pw,
    "status": "active",
    "roles": roles.split(","),
}))
PY
)

curl -fsS -u "admin:$PASS" -X POST "$API/users" -H 'Content-Type: application/json' -d "$BODY" >/dev/null
echo "user:     $ID"
echo "roles:    $ROLES"
echo "password: $PW"