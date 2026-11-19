#!/usr/bin/env bash
# pypi-all: what pip uses. hosted first, then proxy.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
create pypi-all pypi/group '{
  "name": "pypi-all", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "group": {"memberNames": ["pypi-hosted", "pypi-proxy"]}}'
