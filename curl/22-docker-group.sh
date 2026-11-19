#!/usr/bin/env bash
# docker-all: what clients use (connector port 5000, routed by Caddy on /v2/)
set -euo pipefail
. "$(dirname "$0")/_env.sh"
create docker-all docker/group '{
  "name": "docker-all", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "group": {"memberNames": ["docker-hosted", "docker-proxy"]},
  "docker": {"v1Enabled": false, "forceBasicAuth": false, "httpPort": 5000}}'
