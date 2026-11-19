#!/usr/bin/env bash
# Checks the configuration before `docker compose up`. Exit 1 on any failure.
set -uo pipefail
. "$(dirname "$0")/../env.sh"
FAIL=0
ok()   { echo "ok    $*"; }
bad()  { echo "FAIL  $*"; FAIL=1; }

# .env
[ -f .env ] && ok ".env present" || bad ".env missing (cp .env.example .env)"
if [ -f .env ]; then
  [ "$(stat -c %a .env)" = 600 ] && ok ".env mode 600" || bad ".env must be mode 600 (chmod 600 .env)"
fi

# pinned versions
for v in NEXUS_TAG CADDY_TAG; do
  val=${!v:-}
  case "$val" in
    ""|latest|[0-9]) bad "$v must be a full pinned version (got '${val}')" ;;
    *) ok "$v=$val" ;;
  esac
done
[ -n "${NEW_ADMIN_PASSWORD:-}" ] && [ "${NEW_ADMIN_PASSWORD}" != "change-me" ] \
  && ok "admin password set" || bad "set NEW_ADMIN_PASSWORD in .env"

# secrets key
if [ -d "$KEY" ]; then bad "$KEY is a directory (compose created it): rmdir it, then run ./scripts/server/secrets.sh init"
elif [ -f "$KEY" ]; then ok "$KEY present"; else bad "$KEY missing (./scripts/server/secrets.sh init)"; fi

# certificate
CRT=certs/tls.crt; PRIV=certs/tls.key
if [ -f "$CRT" ] && [ -f "$PRIV" ]; then
  ok "certificate and key present"
  a=$(openssl x509 -in "$CRT" -noout -pubkey | openssl sha256)
  b=$(openssl pkey -in "$PRIV" -pubout 2>/dev/null | openssl sha256)
  [ "$a" = "$b" ] && ok "key matches certificate" || bad "certs/tls.key does not match certs/tls.crt"
  openssl x509 -in "$CRT" -noout -checkend $((30*86400)) >/dev/null \
    && ok "certificate valid for more than 30 days" || bad "certificate expires within 30 days (or already expired)"
  IFS=',' read -ra ADDR <<< "${SITE_ADDRESSES:-}"
  for n in "${ADDR[@]}"; do
    n=${n// /}; [ -z "$n" ] && continue
    if [[ $n =~ ^[0-9.]+$ ]]; then openssl x509 -in "$CRT" -noout -checkip "$n" | grep -q "does match" \
      && ok "certificate covers $n" || bad "certificate does not cover IP $n"
    else openssl x509 -in "$CRT" -noout -checkhost "$n" | grep -q "does match" \
      && ok "certificate covers $n" || bad "certificate does not cover $n"
    fi
  done
  [ "$(stat -c %a "$PRIV")" = 600 ] && ok "tls.key mode 600" || bad "chmod 600 certs/tls.key"
else
  bad "certs/tls.crt and certs/tls.key missing"
fi

# compose
$COMPOSE config -q 2>/dev/null && ok "compose file valid" || bad "compose config failed ($COMPOSE)"

[ "$FAIL" = 0 ] && echo "preflight passed" || { echo "preflight failed"; exit 1; }
