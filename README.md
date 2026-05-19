# dbt SQL Server example — Python models vs DuckDB mssql extension

[![CI](https://github.com/oluies/dbtex007/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/oluies/dbtex007/actions/workflows/ci.yml?query=branch%3Amain)
[![dbt-duckdb](https://img.shields.io/badge/dbt--duckdb-%E2%89%A51.10.1-FF694B?logo=dbt&logoColor=white)](https://github.com/duckdb/dbt-duckdb)
[![DuckDB](https://img.shields.io/badge/DuckDB-%E2%89%A51.5.2-FFF000?logo=duckdb&logoColor=black)](https://duckdb.org)
[![mssql extension](https://img.shields.io/badge/mssql%20extension-hugr--lab-181717?logo=github&logoColor=white)](https://github.com/hugr-lab/mssql-extension)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2025--latest-CC2927?logo=microsoftsqlserver&logoColor=white)](https://hub.docker.com/_/microsoft-mssql-server)

Two dbt projects that copy the same tables from one SQL Server to another,
using different mechanisms. The point is to compare them side by side.

- **`projects/dbt_python_copy`** — `dbt-duckdb` adapter with **Python models**.
  Each model uses `pymssql` + SQLAlchemy to read a table from the source and
  write it to the destination. DuckDB is only the orchestrator.
- **`projects/dbt_duckdb_mssql`** — `dbt-duckdb` adapter with the
  [`mssql` community DuckDB extension](https://github.com/hugr-lab/mssql-extension).
  A custom `mssql_native` materialization `INSTALL`s/`LOAD`s the extension,
  `ATTACH`es both SQL Server databases, and pushes
  `CREATE OR REPLACE TABLE dst.ddd.<table> AS SELECT * FROM src.ddd.<table>`
  over native TDS — no Python in the hot path.

The seed data is a small slice of the Domain-Driven Design cargo-shipping
sample (per [oluies/ddd-sample-scala](https://github.com/oluies/ddd-sample-scala)):
`locations`, `voyages`, `cargo`, `itinerary`, `legs`, `handling_events`.

## Layout

```
.
├── docker-compose.yml          # two SQL Server 2025 containers (source + dest)
├── docker/mssql-init/
│   ├── entrypoint.sh           # Microsoft's "background sqlservr + poll + run *.sql" pattern
│   ├── source/01_schema.sql
│   ├── source/02_seed.sql
│   └── dest/01_schema.sql      # creates ddd_dest only; tables come from dbt
├── projects/
│   ├── dbt_python_copy/        # Project A — Python models
│   └── dbt_duckdb_mssql/       # Project B — mssql community extension
├── Makefile
├── .env.example
└── README.md
```

## Prerequisites

- Docker Desktop (or Colima) — on Apple Silicon the official
  `mcr.microsoft.com/mssql/server:2025-latest` image runs under Rosetta
  emulation. Slow first start but works. See **ARM Macs** below for the
  faster `azure-sql-edge` alternative.
- Python 3.10+ on the host (used by both dbt projects).
- `make`.

## Quick start

```bash
cp .env.example .env             # tweak the SA password if you like
make up                          # start both SQL Servers + apply init SQL
make seed-check                  # confirm the source has data

# Either approach copies the same six tables to dest:
make run-python                  # Project A — Python models, ~30s
# or
make run-duckdb                  # Project B — DuckDB mssql extension, ~5s

make verify                      # row counts on source vs dest
```

`make up` blocks until both containers report healthy and the init SQL
has run.

## Project A — `dbt_python_copy`

Each Python model has the same shape:

```python
def model(dbt, session):
    dbt.config(materialized="table", packages=["pymssql", "pandas", "sqlalchemy"])
    src = create_engine(os.environ["SRC_MSSQL_URL"])
    dst = create_engine(os.environ["DST_MSSQL_URL"])
    df = pd.read_sql("SELECT * FROM ddd.locations", src)
    with dst.begin() as conn:
        conn.execute(text("IF OBJECT_ID('ddd.locations','U') IS NOT NULL DROP TABLE ddd.locations"))
    df.to_sql("locations", dst, schema="ddd", if_exists="append",
              index=False, method="multi", chunksize=500)
    return pd.DataFrame({"table": ["locations"], "rows_copied": [len(df)]})
```

The returned sentinel DataFrame becomes a tiny audit table in the local
`audit.duckdb` — that's how dbt-duckdb tracks "this model ran". The
real side-effect is the `to_sql` write into the destination SQL Server.

**Why `pymssql` over `pyodbc`?** Pure-Python wheel, no `msodbcsql18`
install on macOS. For >100k rows you'll want `pyodbc` with
`fast_executemany`; for this demo `pymssql` is plenty.

## Project B — `dbt_duckdb_mssql`

A custom materialization (`macros/materialization_mssql_native.sql`,
adapted from [oluies/dbt_duckdb_sqlserver](https://github.com/oluies/dbt_duckdb_sqlserver))
does the heavy lifting. Models are one-liners:

```sql
SELECT * FROM {{ source('src_ddd', 'locations') }}
```

The materialization rewrites that into:

```sql
INSTALL mssql FROM community;
LOAD mssql;
ATTACH IF NOT EXISTS '<src conn>' AS src (TYPE mssql, READ_ONLY);
ATTACH IF NOT EXISTS '<dst conn>' AS dst (TYPE mssql);
CREATE OR REPLACE TABLE dst.ddd.locations AS SELECT * FROM (
    SELECT * FROM src.ddd.locations
) _q;
```

DuckDB streams rows over TDS in both directions; no intermediate Python
object, no pandas frame.

Connection strings come from `SRC_MSSQL_DUCKDB_CONN` and
`DST_MSSQL_DUCKDB_CONN` in `.env`. They are ADO.NET-style:
`Server=host,port;Database=db;User Id=sa;Password=...;TrustServerCertificate=true;Encrypt=false`.

### Multi-database background

Project B leans on DuckDB's
[multi-database ATTACH model](https://duckdb.org/2024/01/26/multi-database-support-in-duckdb).
The same pattern works for `postgres`, `mysql`, and `sqlite` out of the box;
SQL Server is enabled by the third-party `mssql` community extension. Once
both catalogs are attached, three-part names (`src.ddd.locations`,
`dst.ddd.locations`) let DuckDB plan a single query that streams rows from
one foreign engine to another with no intermediate file or Python frame.

Two consequences worth knowing:

- **`COPY FROM DATABASE ... TO`** is a one-shot way to clone an entire
  attached database. We don't use it in dbt because there's no per-table
  DAG node, but `projects/dbt_duckdb_mssql/analyses/bulk_copy.sql` shows
  the equivalent single-statement migration for reference.
- **A single transaction may only write to one attached database.** That's
  why `disable_transactions: true` is set in the dbt profile — dbt's
  default `BEGIN ... COMMIT` wrapping would otherwise conflict with the
  extension's own per-statement commit on the destination.

## When to use which

| Concern | Project A (Python) | Project B (mssql ext) |
|---|---|---|
| Setup cost on a fresh machine | pip install pymssql/pandas/sqlalchemy | install one DuckDB extension |
| Speed for ~100 rows | ok | faster (no Python serialize) |
| Speed for >1M rows | needs `pyodbc` + `fast_executemany` | streams natively, no buffering |
| Type fidelity | pandas dtype mapping (quirky for `decimal`, `datetime2`, `nvarchar(max)`) | extension preserves types end-to-end |
| Custom row-level Python logic between source and dest | yes — it's just pandas | no — pure SQL |
| Schema evolution / alter | manual in the model | `CREATE OR REPLACE TABLE` regenerates schema |
| Skill required | pandas | DuckDB SQL |

A common production pattern: Project B for plain copies, Project A
where you actually need Python (calling out to APIs, applying ML models,
parsing custom binary formats).

## ARM Macs

`mssql/server` is an amd64 image; `platform: linux/amd64` in
`docker-compose.yml` lets Docker emulate it via Rosetta. It works but
first-time pulls + startup are slow.

The faster alternative is Microsoft's Azure SQL Edge image (native ARM):

```yaml
# in docker-compose.yml, replace `image:` and drop `platform:`
image: mcr.microsoft.com/azure-sql-edge:latest
# environment variable name differs:
environment:
  ACCEPT_EULA: "Y"
  MSSQL_SA_PASSWORD: "${MSSQL_SA_PASSWORD}"
```

Edge reports as SQL Server 2022-compatible and the `mssql` extension's
README states "SQL Server 2019 or later", so it should work. Verify
with `make run-duckdb` against a single table before committing.

## TLS / `TrustServerCertificate`

SQL Server containers ship with a self-signed cert that neither
`pymssql` nor the `mssql` extension will trust by default. The provided
connection strings include `TrustServerCertificate=true;Encrypt=false`,
which is appropriate for local development only. In production, mount
real certs and set `Encrypt=true;TrustServerCertificate=false`.

## DuckDB memory tuning

Both profiles cap DuckDB's resource use per the
[OOM guide](https://duckdb.org/docs/current/guides/performance/oom):

| Setting | Default | What it does |
|---|---|---|
| `memory_limit` | `512MB` | Hard cap on the DuckDB buffer manager. Default would be 80% of RAM. Anything that doesn't fit spills to `temp_directory`. |
| `threads` | `4` | Parallelism for DuckDB operators. More threads → more peak memory. |
| `preserve_insertion_order` | `false` | Recommended for large reads/writes; lower memory overhead. |
| `temp_directory` | `target/duckdb_spill` | On-disk spill target so queries that exceed `memory_limit` succeed instead of OOM. Cleared by `make clean`. |
| `max_temp_directory_size` | `10GB` | Cap on the spill directory. |

Override via env vars before running dbt:

```bash
DUCKDB_MEMORY_LIMIT=12GB DUCKDB_THREADS=8 make run-duckdb
```

## Troubleshooting

- **Container exits silently right after start** — the SA password
  didn't pass SQL Server's complexity check. Make sure it has uppercase,
  lowercase, a digit, and a symbol; 8+ chars.
- **`make run-python` errors on `pymssql` install on macOS** — `pip
  install pymssql` needs `freetds` headers. Run
  `brew install freetds openssl` and retry, or fall back to
  `pyodbc` + `msodbcsql18` (`brew tap microsoft/mssql-release && brew
  install msodbcsql18`).
- **`make run-duckdb` fails on `INSTALL mssql FROM community`** — your
  DuckDB version is too old. The extension requires v1.4.1+. Bump the
  pin in `projects/dbt_duckdb_mssql/requirements.txt`.
- **Port 1433 conflict on the host** — host ports `11433` and `21433`
  are used so the standard 1433 stays free. If those collide, edit
  `docker-compose.yml` and `.env` together.
- **dbt logs "transaction was deadlocked"** — `disable_transactions:
  true` should already be set in `projects/dbt_duckdb_mssql/profiles.yml`;
  check it wasn't overridden by `~/.dbt/profiles.yml`.

## CI & dependency updates

`.github/workflows/ci.yml` runs on every push and PR:

1. **`lint`** — matrix over both projects. Installs `requirements.txt`,
   runs `dbt parse`. No SQL Server needed; env_var lookups are stubbed.
2. **`integration`** — matrix over both projects. `docker compose up
   --wait`, waits for seed completion, runs `dbt run`, then asserts
   each destination table's row count equals the source. Logs are
   dumped on failure.

`.github/dependabot.yml` watches:

- `pip` in each `projects/*/requirements.txt` (grouped: dbt adapters
  together, pandas/sqlalchemy/pymssql together).
- `docker-compose` at the repo root for the `mcr.microsoft.com/mssql/server`
  image tag.
- `github-actions` for the workflow itself.

There is no Dependabot ecosystem for dbt's `packages.yml` — neither
project uses dbt-hub packages today, so it's a non-issue. If you add any
later, switch to [Renovate with a custom regex manager](https://docs.renovatebot.com/modules/manager/regex/).

## What's out of scope

- dbt tests / snapshots / freshness — meaningful for Project A,
  awkward for Project B (would re-query SQL Server through the
  extension). Add as a follow-up if you want to see how they behave.
- Incremental materializations — `mssql_native` supports `truncate` and
  `append` strategies (see the macro docstring) but every model here
  uses `replace`.
- CI / GitHub Actions — local-only demo.
- Production hardening — see TLS section.

## References

- DDD cargo sample (Scala port): https://github.com/oluies/ddd-sample-scala
- mssql DuckDB community extension: https://github.com/hugr-lab/mssql-extension
- DuckDB multi-database support (the pattern Project B uses):
  https://duckdb.org/2024/01/26/multi-database-support-in-duckdb
- DuckDB OOM tuning guide (the memory settings):
  https://duckdb.org/docs/current/guides/performance/oom
- Reference dbt-duckdb + SQL Server project this is adapted from:
  https://github.com/oluies/dbt_duckdb_sqlserver
