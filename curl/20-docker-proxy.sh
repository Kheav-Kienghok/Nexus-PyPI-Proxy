#!/usr/bin/env bash
# docker-proxy: cache of Docker Hub (connector port 5001).
# Uses DOCKERHUB_USER / DOCKERHUB_TOKEN from .env when set.
set -euo pipefail
. "$(dirname "$0")/_env.sh"

HUB_AUTH=""
if [ -n "${DOCKERHUB_USER:-}" ]; then
  HUB_AUTH=", \"authentication\": {\"type\": \"username\", \"username\": \"$DOCKERHUB_USER\", \"password\": \"${DOCKERHUB_TOKEN:?set DOCKERHUB_TOKEN}\"}"
fi

create docker-proxy docker/proxy '{
  "name": "docker-proxy", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "proxy": {"remoteUrl": "https://registry-1.docker.io", "contentMaxAge": 1440, "metadataMaxAge": 1440},
  "negativeCache": {"enabled": true, "timeToLive": 1440},
  "httpClient": {"blocked": false, "autoBlock": true'"$HUB_AUTH"'},
  "docker": {"v1Enabled": false, "forceBasicAuth": false, "httpPort": 5001},
  "dockerProxy": {"indexType": "HUB"}}'
