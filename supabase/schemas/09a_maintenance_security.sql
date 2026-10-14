-- Maintenance RLS policies. Apply after 09_maintenance.sql.
alter table public.maintenance_assets enable row level security;
alter table public.maintenance_plans enable row level security;
alter table public.maintenance_work_orders enable row level security;
alter table public.maintenance_spare_requirements enable row level security;
alter table public.maintenance_events enable row level security;

create policy maintenance_assets_read on public.maintenance_assets for select to authenticated
 using ((select private.has_permission(organization_id,'maintenance.read',factory_id)));
create policy maintenance_assets_manage on public.maintenance_assets for all to authenticated
 using ((select private.has_permission(organization_id,'maintenance.manage',factory_id)))
 with check ((select private.has_permission(organization_id,'maintenance.manage',factory_id)));
create policy maintenance_plans_read on public.maintenance_plans for select to authenticated
 using ((select private.has_permission(organization_id,'maintenance.read',factory_id)));
create policy maintenance_plans_manage on public.maintenance_plans for all to authenticated
 using ((select private.has_permission(organization_id,'maintenance.manage',factory_id)))
 with check ((select private.has_permission(organization_id,'maintenance.manage',factory_id)));
create policy maintenance_orders_read on public.maintenance_work_orders for select to authenticated
 using ((select private.has_permission(organization_id,'maintenance.read',factory_id)));
create policy maintenance_orders_manage on public.maintenance_work_orders for all to authenticated
 using ((select private.has_permission(organization_id,'maintenance.manage',factory_id)))
 with check ((select private.has_permission(organization_id,'maintenance.manage',factory_id)));
create policy maintenance_spares_read on public.maintenance_spare_requirements for select to authenticated
 using ((select private.has_permission(organization_id,'maintenance.read',factory_id)));
create policy maintenance_spares_manage on public.maintenance_spare_requirements for all to authenticated
 using ((select private.has_permission(organization_id,'maintenance.manage',factory_id)))
 with check ((select private.has_permission(organization_id,'maintenance.manage',factory_id)));
create policy maintenance_events_read on public.maintenance_events for select to authenticated
 using ((select private.has_permission(organization_id,'maintenance.read',factory_id)));
create policy maintenance_events_insert on public.maintenance_events for insert to authenticated
 with check ((select private.has_permission(organization_id,'maintenance.manage',factory_id)));

grant select,insert,update on public.maintenance_assets to authenticated;
grant select,insert,update on public.maintenance_plans to authenticated;
grant select,insert,update on public.maintenance_work_orders to authenticated;
grant select,insert,update,delete on public.maintenance_spare_requirements to authenticated;
grant select,insert on public.maintenance_events to authenticated;
grant usage,select on sequence public.maintenance_events_id_seq to authenticated;
