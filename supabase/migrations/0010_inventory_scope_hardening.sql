begin;

create or replace function public.validate_stock_location_parent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_location_id is not null then
    if not exists (
      select 1 from public.stock_locations p
      where p.id = new.parent_location_id
        and p.organization_id = new.organization_id
        and p.factory_id = new.factory_id
    ) then
      raise exception 'Parent location must belong to the same organization and factory';
    end if;
    if new.parent_location_id = new.id then
      raise exception 'Location cannot be its own parent';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.validate_stock_location_parent() from public;
create trigger stock_locations_validate_parent
before insert or update of parent_location_id,organization_id,factory_id on public.stock_locations
for each row execute function public.validate_stock_location_parent();

create or replace function public.inventory_dashboard_summary(p_organization_id uuid, p_factory_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_inventory_factory(p_factory_id) then raise exception 'Factory access denied'; end if;

  select jsonb_build_object(
    'active_items', (
      select count(*) from public.inventory_items i
      where i.organization_id=p_organization_id and i.is_active
    ),
    'total_quantity', coalesce((
      select sum(le.quantity_delta)
      from public.stock_ledger_entries le
      where le.organization_id=p_organization_id
        and (p_factory_id is null or le.factory_id=p_factory_id)
        and public.can_view_inventory_factory(le.factory_id)
    ),0),
    'low_stock_items', (
      select count(*) from (
        select rr.item_id
        from public.inventory_reorder_rules rr
        left join public.stock_ledger_entries le
          on le.item_id=rr.item_id and le.factory_id=rr.factory_id
        where rr.organization_id=p_organization_id
          and rr.is_active
          and (p_factory_id is null or rr.factory_id=p_factory_id)
          and public.can_view_inventory_factory(rr.factory_id)
        group by rr.id, rr.item_id, rr.reorder_level
        having coalesce(sum(le.quantity_delta),0) <= rr.reorder_level
      ) s
    ),
    'today_movements', (
      select count(*)
      from public.inventory_transactions t
      where t.organization_id=p_organization_id
        and (p_factory_id is null or t.factory_id=p_factory_id)
        and public.can_view_inventory_factory(t.factory_id)
        and t.occurred_at >= date_trunc('day', now())
    )
  ) into result;
  return result;
end;
$$;

grant execute on function public.inventory_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.inventory_lookup_scan(p_organization_id uuid, p_code text)
returns table(item_id uuid,sku text,item_name text,item_type text,barcode text,qr_code text,unit_code text,factory_id uuid,factory_name text,location_id uuid,location_name text,quantity numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if char_length(trim(coalesce(p_code,''))) < 2 then raise exception 'Scan code is required'; end if;
  return query
  with matched as (
    select i.* from public.inventory_items i
    where i.organization_id=p_organization_id
      and i.is_active
      and (upper(i.sku)=upper(trim(p_code)) or i.barcode=trim(p_code) or i.qr_code=trim(p_code))
    limit 1
  )
  select m.id,m.sku,m.name,m.item_type,m.barcode,m.qr_code,u.code,f.id,f.name,l.id,l.name,coalesce(sum(le.quantity_delta),0)::numeric
  from matched m
  join public.inventory_units u on u.id=m.unit_id
  join public.stock_locations l
    on l.organization_id=m.organization_id
   and l.is_active
   and public.can_view_inventory_factory(l.factory_id)
  join public.factories f on f.id=l.factory_id
  left join public.stock_ledger_entries le on le.item_id=m.id and le.location_id=l.id
  group by m.id,m.sku,m.name,m.item_type,m.barcode,m.qr_code,u.code,f.id,f.name,l.id,l.name
  order by f.name,l.name;
end;
$$;

grant execute on function public.inventory_lookup_scan(uuid,text) to authenticated;

commit;
