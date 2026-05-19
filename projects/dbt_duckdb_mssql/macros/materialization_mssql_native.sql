{#
    mssql_native materialization — pushes a DuckDB query result into SQL Server
    using the `mssql` community DuckDB extension (native TDS, no pyodbc /
    SQLAlchemy roundtrip).

    Docs:
      https://duckdb.org/community_extensions/extensions/mssql
      https://github.com/hugr-lab/mssql-extension

    Adapted from https://github.com/oluies/dbt_duckdb_sqlserver

    Per-model config:
        {{ config(
            materialized='mssql_native',
            target_mssql_schema='ddd',         -- default from dbt_project.yml
            strategy='replace',                -- 'replace' | 'truncate' | 'append'
            src_attach_alias='src',
            dst_attach_alias='dst'
        ) }}

    Required env vars:
      SRC_MSSQL_DUCKDB_CONN — ADO.NET connection string for the source DB
      DST_MSSQL_DUCKDB_CONN — ADO.NET connection string for the destination DB

    Both source and destination are attached so models can `SELECT FROM
    src.ddd.<table>` and the materialization writes the CTAS into
    `dst.ddd.<table>`.
#}

{% materialization mssql_native, adapter='duckdb' %}

    {%- set src_alias = config.get('src_attach_alias', 'src') -%}
    {%- set dst_alias = config.get('dst_attach_alias', 'dst') -%}
    {%- set target_schema = config.get('target_mssql_schema', 'ddd') -%}
    {%- set target_table = model['alias'] or model['name'] -%}
    {%- set strategy = config.get('strategy', 'replace') -%}
    {%- set src_conn = env_var('SRC_MSSQL_DUCKDB_CONN') -%}
    {%- set dst_conn = env_var('DST_MSSQL_DUCKDB_CONN') -%}

    {%- set fqn = dst_alias ~ '.' ~ target_schema ~ '.' ~ target_table -%}

    {% do run_query("INSTALL mssql FROM community") %}
    {% do run_query("LOAD mssql") %}

    {% do run_query(
        "ATTACH IF NOT EXISTS '" ~ src_conn ~ "' AS " ~ src_alias ~ " (TYPE mssql, READ_ONLY)"
    ) %}
    {% do run_query(
        "ATTACH IF NOT EXISTS '" ~ dst_conn ~ "' AS " ~ dst_alias ~ " (TYPE mssql)"
    ) %}

    {%- if strategy == 'replace' -%}
        {% call statement('main') -%}
            CREATE OR REPLACE TABLE {{ fqn }} AS
            SELECT * FROM (
                {{ sql }}
            ) _q
        {%- endcall %}
    {%- elif strategy == 'truncate' -%}
        {% do run_query("DELETE FROM " ~ fqn) %}
        {% call statement('main') -%}
            INSERT INTO {{ fqn }}
            SELECT * FROM (
                {{ sql }}
            ) _q
        {%- endcall %}
    {%- elif strategy == 'append' -%}
        {% call statement('main') -%}
            INSERT INTO {{ fqn }}
            SELECT * FROM (
                {{ sql }}
            ) _q
        {%- endcall %}
    {%- else -%}
        {% do exceptions.raise_compiler_error(
            "mssql_native: unknown strategy '" ~ strategy ~
            "'. Expected 'replace', 'truncate', or 'append'."
        ) %}
    {%- endif %}

    {% set target_relation = api.Relation.create(
        database=dst_alias,
        schema=target_schema,
        identifier=target_table,
        type='table'
    ) %}

    {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
