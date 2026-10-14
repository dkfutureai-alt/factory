-- Minimal Supabase compatibility layer for PostgreSQL CI.
-- This does NOT replace a real Supabase project. It only provides the auth objects/roles
-- required to parse and execute FactoryOS declarative schemas in an isolated CI database.

create extension if not exists pgcrypto;

DO $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated noinherit;
  end if;
end
$$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text unique,
  created_at timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

revoke all on function auth.uid() from public;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
