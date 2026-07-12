-- Test-only shim: emulates the Supabase runtime (auth schema, auth.uid(), the
-- anon/authenticated/service_role roles, default privileges, realtime publication)
-- so the migrations can be run and RLS/RPCs exercised on a plain Postgres.
-- NEVER deployed — Supabase provides all of this in production.

create extension if not exists pgcrypto;

create schema if not exists auth;
create table if not exists auth.users (
  id    uuid primary key default gen_random_uuid(),
  phone text,
  email text
);

-- In production auth.uid() reads the JWT 'sub'. Here it reads a session GUC the
-- test harness sets per simulated user.
create or replace function auth.uid() returns uuid
  language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;

do $$ begin create role anon           nologin noinherit;            exception when duplicate_object then null; end $$;
do $$ begin create role authenticated  nologin noinherit;            exception when duplicate_object then null; end $$;
do $$ begin create role service_role   nologin noinherit bypassrls;  exception when duplicate_object then null; end $$;

grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Supabase auto-grants ALL on new public objects to these roles (RLS then
-- restricts). Emulate via default privileges so every table/function the
-- migrations create is reachable exactly as in production.
alter default privileges in schema public grant all     on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all     on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;

do $$ begin create publication supabase_realtime; exception when duplicate_object then null; end $$;
