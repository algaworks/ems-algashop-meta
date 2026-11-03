create role metabase_reader login password 'metabase_reader';

alter role metabase_reader set default_transaction_read_only = on;
grant connect on database insights to metabase_reader;

\connect insights

grant usage on schema public to metabase_reader;
grant select on all tables in schema public to metabase_reader;

alter default privileges in schema public grant select on tables to metabase_reader;