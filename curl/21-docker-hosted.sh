#!/usr/bin/env bash
# docker-hosted: your own images (connector port 5002, not exposed by Caddy)
set -euo pipefail
. "$(dirname "$0")/_env.sh"
create docker-hosted docker/hosted '{
  "name": "docker-hosted", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "allow"},
  "docker": {"v1Enabled": false, "forceBasicAuth": false, "httpPort": 5002}}'
