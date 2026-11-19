#!/usr/bin/env bash
# Stops Nexus, archives the data volume to backups/, starts Nexus again.
set -euo pipefail
. "$(dirname "$0")/../env.sh"

VOL=${NEXUS_VOLUME:-nexus-data}
OUT="nexus-data-$(date +%F-%H%M).tar.gz"
mkdir -p backups

"$ENGINE" stop nexus
trap '"$ENGINE" start nexus >/dev/null' EXIT
"$ENGINE" run --rm -v "$VOL:/data:ro" -v "$ROOT/backups:/backup:Z" \
  docker.io/library/alpine:3.20 tar czf "/backup/$OUT" -C /data .

# prune old backups
find backups -name 'nexus-data-*.tar.gz' -mtime +"${KEEP_DAYS:-14}" -delete

echo "backup: backups/$OUT"
echo "the key file is not included: copy $KEY separately"
