begin;

-- Phase 15: deterministic database performance hardening.
-- Every public-schema foreign key should have a usable leading-column index.
-- Missing indexes make parent updates/deletes and common joins degrade as data grows.
do $$
declare
  r record;
  v_index_name text;
begin
  for r in
    with foreign_keys as (
      select
        c.oid as constraint_oid,
        c.conname,
        c.conrelid,
        c.conkey,
        n.nspname,
        cls.relname,
        (
          select string_agg(quote_ident(a.attname), ', ' order by key_col.ordinality)
          from unnest(c.conkey) with ordinality as key_col(attnum, ordinality)
          join pg_attribute a
            on a.attrelid=c.conrelid
           and a.attnum=key_col.attnum
        ) as index_columns
      from pg_constraint c
      join pg_class cls on cls.oid=c.conrelid
      join pg_namespace n on n.oid=cls.relnamespace
      where c.contype='f'
        and n.nspname='public'
        and cls.relkind in ('r','p')
    )
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
          select indexed.attnum::smallint
          from unnest(i.indkey::smallint[]) with ordinality as indexed(attnum, ordinality)
          where indexed.ordinality <= cardinality(fk.conkey)
          order by indexed.ordinality
        ) = fk.conkey
    )
    order by fk.nspname,fk.relname,fk.conname
  loop
    v_index_name:=left('qa_fk_'||r.relname,42)||'_'||substr(md5(r.conname),1,8)||'_idx';
    execute format(
      'create index if not exists %I on %I.%I (%s)',
      v_index_name,
      r.nspname,
      r.relname,
      r.index_columns
    );
  end loop;
end $$;

commit;
