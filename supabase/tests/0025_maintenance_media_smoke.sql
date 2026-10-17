begin;

do $$
declare v_public boolean; v_limit bigint; v_types text[]; v_policies integer;
begin
  select public,file_size_limit,allowed_mime_types into v_public,v_limit,v_types
  from storage.buckets where id='maintenance-media';
  if not found then raise exception 'maintenance-media bucket missing'; end if;
  if v_public then raise exception 'maintenance-media bucket must be private'; end if;
  if v_limit<>10485760 then raise exception 'maintenance-media file-size limit mismatch'; end if;
  if not (v_types @> array['image/jpeg','image/png','image/webp']::text[]) then raise exception 'maintenance-media mime restrictions missing'; end if;

  select count(*) into v_policies from pg_policies
  where schemaname='storage' and tablename='objects' and policyname in ('maintenance_media_insert','maintenance_media_select','maintenance_media_update','maintenance_media_delete');
  if v_policies<>4 then raise exception 'maintenance-media storage policies missing'; end if;

  if to_regprocedure('public.maintenance_can_access_media_path(text,text,text)') is null then raise exception 'maintenance media path helper missing'; end if;
end $$;

rollback;
