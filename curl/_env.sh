# Sourced by every script in this folder.
. "$(dirname "${BASH_SOURCE[0]}")/../scripts/env.sh"
: "${PASS:?set NEW_ADMIN_PASSWORD in .env}"

API="$NEXUS_URL/service/rest/v1"
JSON=(-H 'Content-Type: application/json')
AUTH=(-u "admin:$PASS")

exists() { curl -fsS "${AUTH[@]}" "$API/repositories" | grep -Eq "\"name\" *: *\"$1\""; }

# create <name> <format/type> <json body>   (skips when the repository exists)
create() {
  if exists "$1"; then echo "skip $1 (exists)"; return 0; fi
  curl -fsS "${AUTH[@]}" -X POST "$API/repositories/$2" "${JSON[@]}" -d "$3"
  echo "created $1"
}
