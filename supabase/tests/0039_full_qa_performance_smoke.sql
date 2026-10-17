\set ON_ERROR_STOP on

begin;

-- Every application-owned table in the exposed public schema must enforce RLS.
do $$
declare
  missing text;
begin
  select string_agg(format('%I.%I',n.nspname,c.relname),', ' order by c.relname)
  into missing
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and not c.relrowsecurity
    and not exists (
      select 1
      from pg_depend d
      where d.classid='pg_class'::regclass
        and d.objid=c.oid
        and d.deptype='e'
    );

  if missing is not null then
    raise exception 'Public application tables without RLS: %',missing;
  end if;
end $$;

-- Application tables must have a primary key so API updates/deletes and audit
-- references stay deterministic.
do $$
declare
  missing text;
begin
  select string_agg(format('%I.%I',n.nspname,c.relname),', ' order by c.relname)
  into missing
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and not exists(select 1 from pg_index i where i.indrelid=c.oid and i.indisprimary)
    and not exists (
      select 1 from pg_depend d
      where d.classid='pg_class'::regclass
        and d.objid=c.oid
        and d.deptype='e'
    );

  if missing is not null then
    raise exception 'Public application tables without primary keys: %',missing;
  end if;
end $$;

-- Every FK should have an index whose leading columns match the FK columns.
do $$
declare
  missing text;
begin
  with foreign_keys as (
    select c.conname,c.conrelid,c.conkey,n.nspname,cls.relname
    from pg_constraint c
    join pg_class cls on cls.oid=c.conrelid
    join pg_namespace n on n.oid=cls.relnamespace
    where c.contype='f'
      and n.nspname='public'
      and cls.relkind in ('r','p')
  ), missing_fk as (
    select fk.*
    from foreign_keys fk
    where not exists (
      select 1
      from pg_index i
      where i.indrelid=fk.conrelid
        and i.indisvalid
        and i.indisready
        and i.indpred is null
        and i.indexprs is null
        and array(
          select i.indkey[offset]
          from generate_series(0,cardinality(fk.conkey)-1) as offset
          order by offset
        ) = fk.conkey
    )
  )
  select string_agg(format('%I.%I:%I',nspname,relname,conname),', ' order by nspname,relname,conname)
  into missing
  from missing_fk;

  if missing is not null then
    raise exception 'Foreign keys without leading-column indexes: %',missing;
  end if;
end $$;

-- Invalid/not-ready indexes indicate an interrupted or unsafe migration state.
do $$
declare
  broken text;
begin
  select string_agg(format('%I.%I',n.nspname,c.relname),', ' order by c.relname)
  into broken
  from pg_index i
  join pg_class c on c.oid=i.indexrelid
  join pg_class t on t.oid=i.indrelid
  join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public'
    and (not i.indisvalid or not i.indisready);

  if broken is not null then
    raise exception 'Invalid or not-ready public indexes: %',broken;
  end if;
end $$;

-- Authorization must never depend on user-editable user_metadata claims.
do $$
declare
  unsafe text;
begin
  select string_agg(format('%I.%I/%I',schemaname,tablename,policyname),', ' order by tablename,policyname)
  into unsafe
  from pg_policies
  where schemaname='public'
    and (coalesce(qual,'') ilike '%user_metadata%' or coalesce(with_check,'') ilike '%user_metadata%');

  if unsafe is not null then
    raise exception 'RLS policies reference user_metadata: %',unsafe;
  end if;
end $$;

-- No application table should expose direct mutation privileges to anon.
do $$
declare
  exposed text;
begin
  select string_agg(format('%I.%I',n.nspname,c.relname),', ' order by c.relname)
  into exposed
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and (
      has_table_privilege('anon',c.oid,'INSERT')
      or has_table_privilege('anon',c.oid,'UPDATE')
      or has_table_privilege('anon',c.oid,'DELETE')
      or has_table_privilege('anon',c.oid,'TRUNCATE')
    )
    and not exists (
      select 1 from pg_depend d
      where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e'
    );

  if exposed is not null then
    raise exception 'Anonymous mutation privilege on application tables: %',exposed;
  end if;
end $$;

rollback;

select 'Phase 15 structural QA and performance gates passed' as result;
