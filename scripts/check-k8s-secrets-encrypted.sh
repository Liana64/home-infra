#!/usr/bin/env bash
set -eu
rc=0
for f in "$@"; do
  if grep -qiE '^kind:[[:space:]]secret$' "$f"; then
    if ! grep -qiE 'ENC.AES256|^\$patch:[[:space:]]delete' "$f"; then
      echo "Unencrypted Kubernetes secret detected in file: $f" >&2
      rc=1
    fi
  fi
done
exit $rc
