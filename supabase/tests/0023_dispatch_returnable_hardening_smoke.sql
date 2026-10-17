begin;

do $$
declare
  fn text;
begin
  select pg_get_functiondef(
    'public.dispatch_record_returnable(uuid,uuid,numeric,text,text)'::regprocedure
  ) into fn;

  if fn not ilike '%Returnable pickup is closed%' then
    raise exception 'dispatch_record_returnable must reject closed returnable pickups';
  end if;

  if fn not ilike '%status<>''open''%'
     and fn not ilike '%status <> ''open''%'
     and fn not ilike '%status <>%open%' then
    raise exception 'dispatch_record_returnable must enforce open pickup state';
  end if;
end
$$;

rollback;
