#!/usr/bin/env bash
# Waits until Nexus answers (1-3 minutes after the container starts).
set -euo pipefail
. "$(dirname "$0")/_env.sh"
until curl -fsS "$API/status" >/dev/null 2>&1; do echo "waiting for nexus at $NEXUS_URL ..."; sleep 5; done
echo "nexus is up"
