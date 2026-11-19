#!/usr/bin/env bash
# usage: 30-anonymous.sh on | off | status
set -euo pipefail
. "$(dirname "$0")/_env.sh"

case "${1:-status}" in
  on)  ENABLED=true ;;
  off) ENABLED=false ;;
  status) curl -fsS "${AUTH[@]}" "$API/security/anonymous"; echo; exit 0 ;;
  *) echo "usage: $0 on|off|status"; exit 1 ;;
esac

curl -fsS "${AUTH[@]}" -X PUT "$API/security/anonymous" "${JSON[@]}" \
  -d "{\"enabled\": $ENABLED, \"userId\": \"anonymous\", \"realmName\": \"NexusAuthorizingRealm\"}"
echo "anonymous enabled: $ENABLED"
