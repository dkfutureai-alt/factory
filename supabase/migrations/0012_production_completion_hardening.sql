begin;

create or replace function public.production_set_batch_status(p_batch_id uuid,p_status text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  bat public.production_batches%rowtype;
  v_good numeric(18,4);
  v_scrap numeric(18,4);
  v_active integer;
  v_order_output numeric(18,4);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('in_progress','paused','completed','cancelled') then raise exception 'Invalid batch status'; end if;

  select * into bat from public.production_batches where id=p_batch_id for update;
  if not found then raise exception 'Batch not found'; end if;
  if not public.can_operate_production_factory(bat.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if bat.status in ('completed','cancelled') then raise exception 'Closed batch cannot change'; end if;

  select coalesce(sum(good_quantity),0),coalesce(sum(scrap_quantity),0)
  into v_good,v_scrap
  from public.production_outputs
  where batch_id=bat.id;

  if p_status='completed' and v_good+v_scrap < bat.planned_quantity then
    raise exception 'Account for the full batch plan before completion: recorded %, planned %',v_good+v_scrap,bat.planned_quantity;
  end if;

  update public.production_batches
  set status=p_status,
      actual_start_at=case when p_status='in_progress' then coalesce(actual_start_at,now()) else actual_start_at end,
      actual_end_at=case when p_status in ('completed','cancelled') then now() else null end
  where id=bat.id;

  if p_status='completed' then
    select count(*) into v_active
    from public.production_batches
    where order_id=bat.order_id and status in ('planned','in_progress','paused');

    select coalesce(sum(o.good_quantity+o.scrap_quantity),0)
    into v_order_output
    from public.production_outputs o
    join public.production_batches b on b.id=o.batch_id
    where b.order_id=bat.order_id;

    if v_active=0 and v_order_output >= (select planned_quantity from public.production_orders where id=bat.order_id) then
      update public.production_orders
      set status='completed',actual_end_at=now()
      where id=bat.order_id;
    end if;
  end if;

  return jsonb_build_object('batch_id',bat.id,'status',p_status,'good_quantity',v_good,'scrap_quantity',v_scrap);
end;
$$;

grant execute on function public.production_set_batch_status(uuid,text) to authenticated;

commit;