#!/usr/bin/env bash
# pypi-hosted: your own Python packages (a version can be uploaded once)
set -euo pipefail
. "$(dirname "$0")/_env.sh"
create pypi-hosted pypi/hosted '{
  "name": "pypi-hosted", "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "allow_once"}}'
