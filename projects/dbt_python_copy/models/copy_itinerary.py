import os
import pandas as pd
from sqlalchemy import create_engine, text

TABLE = "itinerary"


def model(dbt, session):
    dbt.config(materialized="table", packages=["pymssql", "pandas", "sqlalchemy"])

    src = create_engine(os.environ["SRC_MSSQL_URL"])
    dst = create_engine(os.environ["DST_MSSQL_URL"])

    df = pd.read_sql(f"SELECT * FROM ddd.{TABLE}", src)

    with dst.begin() as conn:
        conn.execute(text(f"IF OBJECT_ID('ddd.{TABLE}','U') IS NOT NULL DROP TABLE ddd.{TABLE}"))
    df.to_sql(TABLE, dst, schema="ddd", if_exists="append",
              index=False, method="multi", chunksize=500)

    return pd.DataFrame({"table": [TABLE], "rows_copied": [len(df)]})
