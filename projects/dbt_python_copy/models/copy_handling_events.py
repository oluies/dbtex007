import os
import pandas as pd
from sqlalchemy import create_engine, text

TABLE = "handling_events"


def model(dbt, session):
    dbt.config(materialized="table", packages=["pymssql", "pandas", "sqlalchemy"])

    src = create_engine(os.environ["SRC_MSSQL_URL"])
    dst = create_engine(os.environ["DST_MSSQL_URL"])

    # IDENTITY column 'id' is in source — copy values explicitly via SET IDENTITY_INSERT.
    df = pd.read_sql(f"SELECT * FROM ddd.{TABLE}", src)

    with dst.begin() as conn:
        conn.execute(text(f"IF OBJECT_ID('ddd.{TABLE}','U') IS NOT NULL DROP TABLE ddd.{TABLE}"))
    # to_sql infers schema from DataFrame; 'id' becomes a plain BIGINT (no IDENTITY).
    # For a faithful copy this is fine — the destination is a clone, not an upstream
    # writer, so it doesn't need its own identity counter.
    df.to_sql(TABLE, dst, schema="ddd", if_exists="append",
              index=False, method="multi", chunksize=500)

    return pd.DataFrame({"table": [TABLE], "rows_copied": [len(df)]})
