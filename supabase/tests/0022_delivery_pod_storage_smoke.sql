begin;

DO $$
DECLARE bucket_public boolean;
DECLARE file_limit bigint;
BEGIN
  select public,file_size_limit into bucket_public,file_limit
  from storage.buckets where id='delivery-pod';

  if bucket_public is null then
    raise exception 'delivery-pod bucket missing';
  end if;
  if bucket_public then
    raise exception 'delivery-pod bucket must remain private';
  end if;
  if file_limit is null or file_limit > 10485760 then
    raise exception 'delivery-pod bucket size limit missing or too large';
  end if;

  if to_regprocedure('public.dispatch_can_access_pod_path(text,text,text)') is null then
    raise exception 'dispatch_can_access_pod_path missing';
  end if;

  if not exists(
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='delivery_pod_insert'
  ) then raise exception 'delivery POD insert policy missing'; end if;

  if not exists(
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='delivery_pod_select'
  ) then raise exception 'delivery POD select policy missing'; end if;
END $$;

rollback;
select 'delivery POD storage smoke checks passed' as result;
