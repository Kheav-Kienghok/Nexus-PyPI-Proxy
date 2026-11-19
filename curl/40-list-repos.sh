#!/usr/bin/env bash
# Lists repositories: name, type, format.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
curl -fsS "${AUTH[@]}" "$API/repositories" | python3 -c '
import json, sys
for r in json.load(sys.stdin):
    print("%-14s %-8s %s" % (r["name"], r["type"], r["format"]))'
