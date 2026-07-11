#!/usr/bin/env bash
set -eu
rc=0
for f in "$@"; do
  if [ "$(sops filestatus "$f" 2>/dev/null)" != '{"encrypted":true}' ]; then
    echo "UNENCRYPTED sops file: $f" >&2
    rc=1
  fi
done
exit $rc
