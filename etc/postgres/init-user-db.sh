#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE USER algashop WITH PASSWORD 'algashop';
	CREATE DATABASE ordering;
	CREATE DATABASE billing;
	GRANT ALL PRIVILEGES ON DATABASE ordering TO algashop;
	GRANT ALL PRIVILEGES ON DATABASE billing TO algashop;
EOSQL