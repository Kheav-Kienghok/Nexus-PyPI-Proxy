#!/usr/bin/env bash
# First run: replaces the generated admin password with NEW_ADMIN_PASSWORD.
set -euo pipefail
. "$(dirname "$0")/_env.sh"

if "$ENGINE" exec nexus test -f /nexus-data/admin.password 2>/dev/null; then
  INITIAL=$("$ENGINE" exec nexus cat /nexus-data/admin.password)
  curl -fsS -u "admin:$INITIAL" -X PUT "$API/security/users/admin/change-password" \
    -H 'Content-Type: text/plain' -d "$PASS"
  echo "admin password changed"
else
  echo "admin password already changed"
fi

curl -fsS "${AUTH[@]}" "$API/security/anonymous" >/dev/null \
  || { echo "admin login failed: NEW_ADMIN_PASSWORD must be the current admin password"; exit 1; }
