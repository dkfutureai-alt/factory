begin;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('maintenance-media','maintenance-media',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.maintenance_can_access_media_path(p_organization_id text,p_factory_id text,p_work_order_id text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.maintenance_work_orders w
    where w.organization_id::text=p_organization_id
      and w.factory_id::text=p_factory_id
      and w.id::text=p_work_order_id
      and public.maintenance_can_view_work_order(w.id)
  );
$$;
revoke all on function public.maintenance_can_access_media_path(text,text,text) from public;
grant execute on function public.maintenance_can_access_media_path(text,text,text) to authenticated;

drop policy if exists maintenance_media_insert on storage.objects;
drop policy if exists maintenance_media_select on storage.objects;
drop policy if exists maintenance_media_update on storage.objects;
drop policy if exists maintenance_media_delete on storage.objects;

create policy maintenance_media_insert on storage.objects for insert to authenticated
with check(
  bucket_id='maintenance-media'
  and array_length(storage.foldername(name),1)=4
  and public.maintenance_can_access_media_path((storage.foldername(name))[1],(storage.foldername(name))[2],(storage.foldername(name))[3])
  and (storage.foldername(name))[4]=auth.uid()::text
);

create policy maintenance_media_select on storage.objects for select to authenticated
using(
  bucket_id='maintenance-media'
  and array_length(storage.foldername(name),1)=4
  and public.maintenance_can_access_media_path((storage.foldername(name))[1],(storage.foldername(name))[2],(storage.foldername(name))[3])
);

create policy maintenance_media_update on storage.objects for update to authenticated
using(
  bucket_id='maintenance-media'
  and array_length(storage.foldername(name),1)=4
  and public.maintenance_can_access_media_path((storage.foldername(name))[1],(storage.foldername(name))[2],(storage.foldername(name))[3])
  and (storage.foldername(name))[4]=auth.uid()::text
)
with check(
  bucket_id='maintenance-media'
  and array_length(storage.foldername(name),1)=4
  and public.maintenance_can_access_media_path((storage.foldername(name))[1],(storage.foldername(name))[2],(storage.foldername(name))[3])
  and (storage.foldername(name))[4]=auth.uid()::text
);

create policy maintenance_media_delete on storage.objects for delete to authenticated
using(
  bucket_id='maintenance-media'
  and array_length(storage.foldername(name),1)=4
  and public.maintenance_can_access_media_path((storage.foldername(name))[1],(storage.foldername(name))[2],(storage.foldername(name))[3])
  and (storage.foldername(name))[4]=auth.uid()::text
);

commit;
