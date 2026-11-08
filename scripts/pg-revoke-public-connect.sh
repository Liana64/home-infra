#!/usr/bin/env bash
set -euo pipefail

cluster="${1:?usage: pg-revoke-public-connect.sh <cnpg-cluster> [--apply]}"
mode="${2:-}"
pod=$(kubectl -n database get pods -l "cnpg.io/cluster=${cluster},role=primary" -o name | head -1)

sql=$(cat <<'SQL'
SELECT format('REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC;', datname)
  FROM pg_database WHERE datallowconn AND NOT datistemplate
UNION ALL
SELECT format('GRANT CONNECT ON DATABASE %I TO cnpg_metrics_exporter;', datname)
  FROM pg_database WHERE datallowconn AND NOT datistemplate
UNION ALL
SELECT 'GRANT CONNECT ON DATABASE postgres TO streaming_replica;'
SQL
)

if [[ "$mode" == "--apply" ]]; then
  printf '%s\n\\gexec\n' "$sql" | kubectl -n database exec -i "$pod" -c postgres -- psql -X -q -v ON_ERROR_STOP=1 --single-transaction >/dev/null
  kubectl -n database exec -i "$pod" -c postgres -- psql -X -At -F' | ' \
    -c "SELECT datname, datacl FROM pg_database WHERE NOT datistemplate ORDER BY 1;"
else
  kubectl -n database exec -i "$pod" -c postgres -- psql -X -At -c "$sql"
fi
