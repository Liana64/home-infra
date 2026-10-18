#!/bin/sh
while :; do
  for op in 1 2; do
    PORT=$(printf "\0\\$op\0\0\0\0\0\0\0\0\0\74" | timeout 5 nc -u -w 2 10.2.0.1 5351 | od -An -tu1 | awk 'NF == 16 && $3 + $4 == 0 { print $11 * 256 + $12 }')
  done
  if [ -z "$PORT" ]; then
    echo "natpmp: no mapping from 10.2.0.1"
  else
    [ "$PORT" = "$LAST" ] || echo "natpmp: forwarded port $PORT"
    LAST=$PORT
    PORT=$PORT sh -c "$NATPMP_SYNC" || echo "natpmp: sync of port $PORT failed"
  fi
  sleep 30
done
