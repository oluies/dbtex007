#!/usr/bin/env bash
# Microsoft's official sample pattern: launch sqlservr in the background, poll
# until it answers SELECT 1, then run every .sql file in /init/sql in
# lexicographic order. Once init succeeds we wait on the server PID so the
# container stays alive.
set -euo pipefail

SQLCMD=/opt/mssql-tools18/bin/sqlcmd
SA_PASSWORD="${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set}"

/opt/mssql/bin/sqlservr &
SQLSERVR_PID=$!

echo "[init] Waiting for SQL Server to accept connections..."
for i in {1..60}; do
    if "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -No -Q "SELECT 1" >/dev/null 2>&1; then
        echo "[init] SQL Server is up (after ${i}s)."
        break
    fi
    if [[ $i -eq 60 ]]; then
        echo "[init] SQL Server did not become ready in 60s; aborting." >&2
        kill "$SQLSERVR_PID" || true
        exit 1
    fi
    sleep 1
done

INIT_MARKER=/var/opt/mssql/.dbt_demo_init_done
if [[ -f "$INIT_MARKER" ]]; then
    echo "[init] Marker $INIT_MARKER exists; skipping SQL init."
else
    shopt -s nullglob
    for f in /init/sql/*.sql; do
        echo "[init] Applying $f"
        "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -No -b -i "$f"
    done
    touch "$INIT_MARKER"
    echo "[init] Initialization complete."
fi

wait "$SQLSERVR_PID"
