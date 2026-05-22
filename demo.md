---
marp: true
theme: default
paginate: true
size: 16:9
title: dbt SQL Server copy — Python vs DuckDB mssql extension
---

# dbt SQL Server copy
## Python models vs DuckDB `mssql` extension

A side-by-side demo: two dbt projects copy the **same six tables**
between two SQL Servers — using two very different engines.

DDD cargo-shipping sample · `locations`, `voyages`, `cargo`,
`itinerary`, `legs`, `handling_events`

---

# The setup

```
docker compose up         # SQL Server 2025 ×2 (source + dest)
make seed-check           # confirm source has data
make run-python   # Project A
make run-duckdb   # Project B
make verify               # row counts: source == dest
```

- Both use the **`dbt-duckdb`** adapter
- DuckDB is either the **orchestrator** (A) or the **engine** (B)
- One `make verify` target proves both paths land identical rows

---

# Project A — Python models

```python
def model(dbt, session):
    dbt.config(materialized="table",
               packages=["pymssql", "pandas", "sqlalchemy"])
    df = pd.read_sql("SELECT * FROM ddd.locations", src_engine)
    df.to_sql("locations", dst_engine, schema="ddd",
              if_exists="append", method="multi", chunksize=500)
```

- `pymssql` + SQLAlchemy + pandas
- DuckDB only tracks "this model ran" via a sentinel audit table
- Familiar to anyone who's written a copy script — just wrapped in dbt

---

# Project B — `mssql` community extension

```sql
-- model: one line
SELECT * FROM {{ source('src_ddd', 'locations') }}
```

Custom materialization rewrites it to:

```sql
INSTALL mssql FROM community;  LOAD mssql;
ATTACH '<src>' AS src (TYPE mssql, READ_ONLY);
ATTACH '<dst>' AS dst (TYPE mssql);
CREATE OR REPLACE TABLE dst.ddd.locations
  AS SELECT * FROM src.ddd.locations;
```

Rows stream natively over TDS — **no Python in the hot path**.

---

# Side by side

| Concern | Project A (Python) | Project B (mssql ext) |
|---|---|---|
| Setup | `pip install` 3 libs | one DuckDB extension |
| ~100 rows | ok | faster — no Python serialize |
| >1M rows | needs `pyodbc` + fast_executemany | streams natively |
| Type fidelity | pandas dtype quirks | preserved end-to-end |
| Custom row logic | yes — it's pandas | no — pure SQL |
| Runtime in demo | **~30s** | **~5s** |

Production pattern: **B for plain copies, A when you actually need Python.**

---

# Takeaways

- **dbt-duckdb** is the same adapter for both — only the *model body*
  and a custom materialization differ
- DuckDB's **multi-database ATTACH** (Postgres, MySQL, SQLite, +
  community `mssql`) turns cross-DB copies into one SQL statement
- Pick the engine, not the framework: same DAG, same tests, same CI
- Repo: `github.com/oluies/dbtex007` — `make up && make run-duckdb`
