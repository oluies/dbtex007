SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ENV_FILE := .env
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export
endif

PYTHON ?= python3
VENV   := .venv

.PHONY: help up down logs reset seed-check venv install run-python run-duckdb verify clean

help:
	@echo "make up           - start both SQL Server containers (source + dest)"
	@echo "make down         - stop and remove containers (keeps volumes)"
	@echo "make reset        - down with volumes deleted (fresh seed on next 'up')"
	@echo "make logs         - tail container logs"
	@echo "make seed-check   - print source row counts"
	@echo "make venv         - create a shared Python venv at $(VENV)"
	@echo "make install      - install Python deps for both projects"
	@echo "make run-python   - run dbt Project A (Python models via pymssql)"
	@echo "make run-duckdb   - run dbt Project B (DuckDB mssql community extension)"
	@echo "make verify       - compare source vs dest row counts"

up:
	@test -f $(ENV_FILE) || (echo "Missing .env — copy .env.example to .env"; exit 1)
	docker compose up -d --wait

down:
	docker compose down

reset:
	docker compose down -v

logs:
	docker compose logs -f --tail=200

seed-check:
	@docker exec ddd-mssql-source /opt/mssql-tools18/bin/sqlcmd \
	    -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -C -No -d ddd_source -h-1 -W -Q "\
	    SELECT 'locations',        COUNT(*) FROM ddd.locations UNION ALL \
	    SELECT 'voyages',          COUNT(*) FROM ddd.voyages UNION ALL \
	    SELECT 'cargo',            COUNT(*) FROM ddd.cargo UNION ALL \
	    SELECT 'itinerary',        COUNT(*) FROM ddd.itinerary UNION ALL \
	    SELECT 'legs',             COUNT(*) FROM ddd.legs UNION ALL \
	    SELECT 'handling_events',  COUNT(*) FROM ddd.handling_events;"

venv:
	@test -d $(VENV) || $(PYTHON) -m venv $(VENV)
	@. $(VENV)/bin/activate && pip install --upgrade pip

install: venv
	. $(VENV)/bin/activate && pip install -r projects/dbt_python_copy/requirements.txt
	. $(VENV)/bin/activate && pip install -r projects/dbt_duckdb_mssql/requirements.txt

run-python: install
	. $(VENV)/bin/activate && cd projects/dbt_python_copy && \
	    DBT_PROFILES_DIR=. dbt run

run-duckdb: install
	. $(VENV)/bin/activate && cd projects/dbt_duckdb_mssql && \
	    DBT_PROFILES_DIR=. dbt run

verify:
	@echo "== SOURCE =="
	@$(MAKE) -s seed-check
	@echo "== DESTINATION =="
	@docker exec ddd-mssql-dest /opt/mssql-tools18/bin/sqlcmd \
	    -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -C -No -d ddd_dest -h-1 -W -Q "\
	    SELECT s.name + '.' + t.name AS qualified_name, p.rows FROM sys.tables t \
	    JOIN sys.schemas s    ON t.schema_id = s.schema_id \
	    JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1) \
	    WHERE s.name = 'ddd' ORDER BY t.name;"

clean:
	rm -rf $(VENV) projects/*/target projects/*/dbt_packages projects/*/logs projects/*/*.duckdb*
