#!/bin/bash
set -e
PSQL="psql -v ON_ERROR_STOP=1 --username ${POSTGRES_USER:-postgres} --dbname ${POSTGRES_DB:-postgres}"

$PSQL <<-EOSQL
	CREATE DATABASE metabase;
EOSQL

$PSQL -f /etc/postgres/metabase-readonly-user.sql