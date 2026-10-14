insert into public.maintenance_work_orders(
 organization_id,factory_id,order_number,asset_id,job_type,priority,status,
 problem_description,reported_at,started_at,completed_at,root_cause,resolution,safety_cleared
)
select a.organization_id,a.factory_id,w.number,a.id,w.kind::public.maintenance_job_type,
 w.priority::public.maintenance_priority,w.status::public.maintenance_job_status,
 w.description,w.reported,w.started,w.finished,w.cause,w.resolution,w.safety
from (values
 ('WO-2026-00241','AC-02','breakdown','critical','in_progress','High bearing temperature',
  timestamptz '2026-10-14 09:50+05:30',timestamptz '2026-10-14 10:30+05:30',null::timestamptz,null::text,null::text,false),
 ('WO-2026-00242','CL-01','corrective','high','waiting_parts','Drive belt wear',
  timestamptz '2026-10-14 08:00+05:30',timestamptz '2026-10-14 08:30+05:30',null::timestamptz,null::text,null::text,false),
 ('WO-2026-00212','AC-02','preventive','normal','completed','Routine lubrication',
  timestamptz '2026-09-18 09:00+05:30',timestamptz '2026-09-18 09:30+05:30',timestamptz '2026-09-18 11:00+05:30','Normal wear','Lubricated and inspected',true)
) w(number,asset_code,kind,priority,status,description,reported,started,finished,cause,resolution,safety)
join public.maintenance_assets a on a.asset_code=w.asset_code
join public.organizations o on o.id=a.organization_id and o.code='DKIM'
on conflict (organization_id,order_number) do nothing;
