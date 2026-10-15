-- FactoryOS Purchase Order decision audit type fix.
-- Approval/rejection decision text is validated before casting into the shared audit_action enum.

create or replace function public.decide_purchase_order(
  target_purchase_order_id uuid,
  target_decision text,
  target_comment text,
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
  decision text := lower(btrim(coalesce(target_decision,'')));
  request_hash text;
  replay_po_id uuid;
  command_type text;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if decision not in ('approve','reject') then raise exception 'purchase order decision must be approve or reject'; end if;
  if decision='reject' and length(btrim(coalesce(target_comment,''))) < 3 then raise exception 'purchase order rejection reason is required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;

  select * into po from public.purchase_orders where id=target_purchase_order_id for update;
  if po.id is null then raise exception 'purchase order not found'; end if;
  if not private.has_factory_permission(po.organization_id,'approval.act',po.factory_id) then
    raise exception 'purchase order approval permission denied';
  end if;

  command_type := case when decision='approve' then 'approve' else 'reject' end;
  request_hash := md5(jsonb_build_object(
    'purchase_order_id',po.id,
    'decision',decision,
    'comment',coalesce(btrim(target_comment),'')
  )::text);

  perform pg_advisory_xact_lock(hashtextextended(po.organization_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(po.organization_id,target_idempotency_key,command_type,request_hash,po.id);
  if replay_po_id is not null then
    select * into po from public.purchase_orders where id=replay_po_id;
    return po;
  end if;

  if po.status <> 'pending_approval' then raise exception 'purchase order is not pending approval'; end if;

  if decision='approve' then
    update public.purchase_orders
    set status='approved',approved_by=actor_id,approved_at=now(),approval_comment=nullif(btrim(coalesce(target_comment,'')),''),
        rejected_by=null,rejected_at=null,rejection_reason=null,revision=revision+1
    where id=po.id returning * into po;
  else
    update public.purchase_orders
    set status='draft',rejected_by=actor_id,rejected_at=now(),rejection_reason=btrim(target_comment),approval_comment=null,
        approved_by=null,approved_at=null,revision=revision+1
    where id=po.id returning * into po;
  end if;

  perform private.record_purchase_command(po.organization_id,po.id,command_type,target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(
    po.organization_id,
    po.factory_id,
    actor_id,
    decision::public.audit_action,
    'purchase_order',
    po.id::text,
    jsonb_build_object(
      'source','purchase_order_workflow',
      'command',command_type,
      'order_number',po.order_number,
      'revision',po.revision,
      'comment',nullif(btrim(coalesce(target_comment,'')),'')
    )
  );
  return po;
end;
$$;

revoke all on function public.decide_purchase_order(uuid,text,text,text) from public;
grant execute on function public.decide_purchase_order(uuid,text,text,text) to authenticated;