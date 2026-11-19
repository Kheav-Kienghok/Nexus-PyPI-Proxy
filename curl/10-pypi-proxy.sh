#!/usr/bin/env bash
# pypi-proxy: cache of pypi.org
set -euo pipefail
. "$(dirname "$0")/_env.sh"
create pypi-proxy pypi/proxy '{
  "name": "pypi-proxy", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "proxy": {"remoteUrl": "https://pypi.org", "contentMaxAge": 1440, "metadataMaxAge": 1440},
  "negativeCache": {"enabled": true, "timeToLive": 1440},
  "httpClient": {"blocked": false, "autoBlock": true}}'
