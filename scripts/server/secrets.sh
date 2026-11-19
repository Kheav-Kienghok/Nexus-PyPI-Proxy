#!/usr/bin/env bash
# usage: secrets.sh init | encrypt
set -euo pipefail
. "$(dirname "$0")/../env.sh"

case "${1:-}" in
  init)
    [ -f "$KEY" ] && { echo "key exists: $KEY"; exit 0; }
    mkdir -p "$(dirname "$KEY")"; chmod 700 "$(dirname "$KEY")"
    (umask 077; printf '{"active":"key1","keys":[{"id":"key1","key":"%s"}]}\n' "$(openssl rand -base64 32)" > "$KEY")
    chmod 444 "$KEY"   # container user must be able to read it
    echo "created $KEY - back it up outside this server"
    ;;
  encrypt)   # existing installs only: re-encrypt stored secrets with this key
    : "${PASS:?set NEW_ADMIN_PASSWORD in .env}"
    curl -sS -o /dev/null -w 'HTTP %{http_code}\n' -u "admin:$PASS" -X PUT \
      "$NEXUS_URL/service/rest/v1/secrets/encryption/re-encrypt" \
      -H 'Content-Type: application/json' -d '{"secretKeyId": "key1"}'
    ;;
  *) echo "usage: $0 init|encrypt"; exit 1 ;;
esac
