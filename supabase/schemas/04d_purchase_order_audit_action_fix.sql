-- FactoryOS Purchase Order audit action compatibility.
-- Submission is a reusable lifecycle event and is recorded explicitly in the shared audit stream.

alter type public.audit_action add value if not exists 'submit';

create or replace function public.submit_purchase_order(
  target_purchase_order_id uuid,
  target_expected_revision integer,
  target_idempotency_key text
)
returns public.purchase_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  po public.purchase_orders;
  request_hash text;
  replay_po_id uuid;
  line_count bigint;
  invalid_count bigint;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;
  select * into po from public.purchase_orders where id=target_purchase_order_id for update;
  if po.id is null then raise exception 'purchase order not found'; end if;
  if not private.has_factory_permission(po.organization_id,'purchase.manage',po.factory_id) then raise exception 'purchase order management permission denied'; end if;

  request_hash := md5(jsonb_build_object('purchase_order_id',po.id,'expected_revision',target_expected_revision)::text);
  perform pg_advisory_xact_lock(hashtextextended(po.organization_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(po.organization_id,target_idempotency_key,'submit',request_hash,po.id);
  if replay_po_id is not null then
    select * into po from public.purchase_orders where id=replay_po_id;
    return po;
  end if;

  if po.status <> 'draft' then raise exception 'only draft purchase orders can be submitted'; end if;
  if po.revision <> target_expected_revision then raise exception 'purchase order revision conflict'; end if;
  select count(*) into line_count from public.purchase_order_lines where purchase_order_id=po.id;
  if line_count=0 then raise exception 'purchase order requires at least one line before submission'; end if;
  select count(*) into invalid_count
  from public.purchase_order_lines pol
  join public.items i on i.id=pol.item_id
  where pol.purchase_order_id=po.id
    and (i.organization_id<>po.organization_id or i.status<>'active');
  if invalid_count>0 then raise exception 'purchase order contains inactive or cross-tenant items'; end if;
  if not exists(
    select 1 from public.suppliers s
    where s.id=po.supplier_id and s.organization_id=po.organization_id and s.status='active'
  ) then raise exception 'purchase order supplier is inactive or invalid'; end if;

  update public.purchase_orders
  set status='pending_approval',submitted_by=actor_id,submitted_at=now(),approved_by=null,approved_at=null,
      rejected_by=null,rejected_at=null,rejection_reason=null,approval_comment=null,revision=revision+1
  where id=po.id returning * into po;

  perform private.record_purchase_command(po.organization_id,po.id,'submit',target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(po.organization_id,po.factory_id,actor_id,'submit','purchase_order',po.id::text,
    jsonb_build_object(
      'source','purchase_order_workflow',
      'command','submit',
      'order_number',po.order_number,
      'revision',po.revision,
      'status','pending_approval'
    ));
  return po;
end;
$$;

revoke all on function public.submit_purchase_order(uuid,integer,text) from public;
grant execute on function public.submit_purchase_order(uuid,integer,text) to authenticated;