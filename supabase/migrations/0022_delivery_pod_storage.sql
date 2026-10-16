begin;

-- Private proof-of-delivery media. Object paths are:
-- <organization_id>/<factory_id>/<delivery_id>/<user_id>/<filename>
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'delivery-pod',
  'delivery-pod',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public=excluded.public,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.dispatch_can_access_pod_path(
  p_organization_id text,
  p_factory_id text,
  p_delivery_id text
)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.dispatch_deliveries d
    where d.organization_id::text=p_organization_id
      and d.factory_id::text=p_factory_id
      and d.id::text=p_delivery_id
      and public.can_view_dispatch_delivery(d.id)
  );
$$;
revoke all on function public.dispatch_can_access_pod_path(text,text,text) from public;
grant execute on function public.dispatch_can_access_pod_path(text,text,text) to authenticated;

drop policy if exists delivery_pod_insert on storage.objects;
drop policy if exists delivery_pod_select on storage.objects;
drop policy if exists delivery_pod_update on storage.objects;
drop policy if exists delivery_pod_delete on storage.objects;

create policy delivery_pod_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id='delivery-pod'
  and array_length(storage.foldername(name),1)=4
  and public.dispatch_can_access_pod_path(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    (storage.foldername(name))[3]
  )
  and (storage.foldername(name))[4]=auth.uid()::text
);

create policy delivery_pod_select
on storage.objects
for select
to authenticated
using (
  bucket_id='delivery-pod'
  and array_length(storage.foldername(name),1)=4
  and public.dispatch_can_access_pod_path(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    (storage.foldername(name))[3]
  )
);

create policy delivery_pod_update
on storage.objects
for update
to authenticated
using (
  bucket_id='delivery-pod'
  and array_length(storage.foldername(name),1)=4
  and public.dispatch_can_access_pod_path(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    (storage.foldername(name))[3]
  )
  and (storage.foldername(name))[4]=auth.uid()::text
)
with check (
  bucket_id='delivery-pod'
  and array_length(storage.foldername(name),1)=4
  and public.dispatch_can_access_pod_path(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    (storage.foldername(name))[3]
  )
  and (storage.foldername(name))[4]=auth.uid()::text
);

create policy delivery_pod_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id='delivery-pod'
  and array_length(storage.foldername(name),1)=4
  and public.dispatch_can_access_pod_path(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    (storage.foldername(name))[3]
  )
  and (storage.foldername(name))[4]=auth.uid()::text
);

commit;
