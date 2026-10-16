-- Fictional Phase 8 Warehouse demo data. No real person/company data.

insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type,parent_location_id,capacity_quantity,aisle,rack,level_no,sequence_no) values
 ('96000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Raw Receiving','RM-RECV','receiving','44000000-0000-4000-8000-000000000001',500,null,null,null,1),
 ('96000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Raw Material Zone A','RM-ZA','zone','44000000-0000-4000-8000-000000000001',1000,'A',null,null,2),
 ('96000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Raw Bin A-01','RM-A01','bin','96000000-0000-4000-8000-000000000002',250,'A','01',1,1),
 ('96000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Finished Goods Zone A','FG-ZA','zone','44000000-0000-4000-8000-000000000003',500,'A',null,null,1),
 ('96000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Finished Goods Bin A-01','FG-A01','bin','96000000-0000-4000-8000-000000000004',120,'A','01',1,1),
 ('96000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Dispatch Staging','DSP-STAGE','staging','44000000-0000-4000-8000-000000000005',100,'D','STG',0,1)
on conflict (id) do nothing;

insert into public.warehouse_putaway_tasks(
 id,organization_id,factory_id,task_no,goods_receipt_id,item_id,source_location_id,target_location_id,quantity,status,notes,created_at
) values (
 '96100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PUT-DEMO-P8-001','94500000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005','44000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000003',20,'pending','Put passed PPE stock into Raw Bin A-01',now()-interval '3 hours'
) on conflict (id) do nothing;

insert into public.warehouse_pick_lists(
 id,organization_id,factory_id,pick_list_no,sales_order_id,staging_location_id,priority,status,notes,created_at
) values (
 '96200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PICK-DEMO-P8-001','95200000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000006','high','released','Pick four medical oxygen cylinders for the fictional hospital order',now()-interval '2 hours'
) on conflict (id) do nothing;

insert into public.warehouse_pick_lines(
 id,organization_id,pick_list_id,sales_allocation_id,sales_order_line_id,item_id,from_location_id,quantity_required,picked_quantity,status,created_at
) values (
 '96300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','96200000-0000-4000-8000-000000000001','95400000-0000-4000-8000-000000000001','95300000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006','44000000-0000-4000-8000-000000000003',4,0,'pending',now()-interval '2 hours'
) on conflict (id) do nothing;

insert into public.warehouse_cycle_counts(
 id,organization_id,factory_id,count_no,location_id,status,notes,started_at,submitted_at,approved_at,created_at
) values (
 '96400000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','CC-DEMO-P8-001','44000000-0000-4000-8000-000000000001','approved','Historical zero-variance cycle count example',now()-interval '1 day',now()-interval '23 hours',now()-interval '22 hours',now()-interval '1 day'
) on conflict (id) do nothing;

insert into public.warehouse_cycle_count_lines(
 id,organization_id,cycle_count_id,item_id,system_quantity,counted_quantity,variance_quantity,counted_at,notes
)
select '96500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','96400000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005',
       coalesce(sum(quantity_delta),0),coalesce(sum(quantity_delta),0),0,now()-interval '23 hours','Demo exact count'
from public.stock_ledger_entries
where item_id='43000000-0000-4000-8000-000000000005' and location_id='44000000-0000-4000-8000-000000000001'
on conflict (id) do nothing;
