-- Fictional Phase 7 Purchase & Sales demo data. No real person/company data.

insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type) values
 ('44000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Incoming Quality Inspection','IN-QC','quality')
on conflict (id) do nothing;

insert into public.business_partners(id,organization_id,partner_code,name,partner_type,tax_id,contact_person,email,phone,address_line1,city,state,postal_code,country_code,credit_days,notes) values
 ('91000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','SUP-001','Sahyadri Safety Supplies','supplier','27DEMO0001A1Z1','Anaya Demo','orders@sahyadri-demo.example','+91 90000 21001','Demo Industrial Estate','Pune','Maharashtra','411019','IN',15,'Fictional PPE and consumables supplier'),
 ('91000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','SUP-002','BluePeak Gas Components','supplier','27DEMO0002A1Z2','Rohit Demo','sales@bluepeak-demo.example','+91 90000 21002','Demo Engineering Park','Nashik','Maharashtra','422010','IN',30,'Fictional gas-component supplier'),
 ('91000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','CUS-001','Sunrise Care Hospital','customer','27DEMO1001C1Z1','Meera Demo','purchase@sunrise-demo.example','+91 90000 22001','Demo Health Campus','Solapur','Maharashtra','413003','IN',20,'Fictional healthcare customer'),
 ('91000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','CUS-002','NovaFab Engineering','customer','27DEMO1002C1Z2','Kabir Demo','stores@novafab-demo.example','+91 90000 22002','Demo Fabrication Zone','Kolhapur','Maharashtra','416122','IN',30,'Fictional industrial customer')
on conflict (id) do nothing;

insert into public.purchase_requisitions(id,organization_id,factory_id,requisition_no,request_date,required_date,purpose,status,requested_by_employee_id,approved_at,decision_note) values
 ('92000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PR-DEMO-001',current_date-3,current_date+2,'Replenish production-floor PPE stock','converted','35000000-0000-4000-8000-000000000004',now()-interval '2 days','Approved for regular PPE replenishment')
on conflict (id) do nothing;

insert into public.purchase_requisition_lines(id,organization_id,requisition_id,item_id,quantity,estimated_unit_cost,notes) values
 ('92100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005',50,12,'Nitrile gloves for warehouse and production teams')
on conflict (id) do nothing;

insert into public.purchase_orders(id,organization_id,factory_id,purchase_order_no,supplier_id,requisition_id,order_date,expected_date,currency_code,status,notes,approved_at) values
 ('93000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PO-DEMO-P7-001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',current_date-2,current_date,'INR','received','Demo PPE purchase order with incoming quality',now()-interval '2 days')
on conflict (id) do nothing;

insert into public.purchase_order_lines(id,organization_id,purchase_order_id,item_id,ordered_quantity,unit_price,tax_rate,received_quantity,notes) values
 ('93100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005',50,12,18,50,'Fifty boxes/pieces for demo receipt')
on conflict (id) do nothing;

insert into public.quality_inspection_plans(id,organization_id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size,effective_from,notes) values
 ('94000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005','Nitrile Gloves Incoming Inspection','GLOVE-INCOMING','V1','incoming','fixed',5,current_date-20,'Incoming PPE packaging and visual inspection')
on conflict (id) do nothing;

insert into public.quality_plan_checks(id,organization_id,plan_id,sequence_no,parameter_name,check_type,acceptance_text,is_required) values
 ('94100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001',1,'Package seal condition','visual','Seal intact with no contamination or tears',true),
 ('94100000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001',2,'Glove visual condition','visual','No visible holes, damage or contamination',true)
on conflict (id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,unit_cost,external_reference,notes,occurred_at) values
 ('94200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005','P7-GRN-REC-001','receive',50,'44000000-0000-4000-8000-000000000006',12,'GRN-DEMO-P7-001','Purchase goods received into incoming quality',now()-interval '8 hours')
on conflict (id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,occurred_at)
select '10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','94200000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005','44000000-0000-4000-8000-000000000006',50,12,now()-interval '8 hours'
where not exists(select 1 from public.stock_ledger_entries where transaction_id='94200000-0000-4000-8000-000000000001');

insert into public.quality_inspections(id,organization_id,factory_id,inspection_no,plan_id,inspection_type,item_id,lot_batch_no,sample_size,status,overall_result,inspector_employee_id,started_at,completed_at,remarks) values
 ('94300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','QI-P7-IN-001','94000000-0000-4000-8000-000000000001','incoming','43000000-0000-4000-8000-000000000005','GLOVE-LOT-P7-A',5,'completed','pass','35000000-0000-4000-8000-000000000002',now()-interval '7 hours 50 minutes',now()-interval '7 hours 40 minutes','Incoming PPE sample passed')
on conflict (id) do nothing;

insert into public.quality_inspection_results(id,organization_id,factory_id,inspection_id,plan_check_id,result_status,text_value,remarks,occurred_at) values
 ('94400000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','94300000-0000-4000-8000-000000000001','94100000-0000-4000-8000-000000000001','pass','Seal intact','Packaging accepted',now()-interval '7 hours 45 minutes'),
 ('94400000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','94300000-0000-4000-8000-000000000001','94100000-0000-4000-8000-000000000002','pass','No visible defects','Visual sample accepted',now()-interval '7 hours 42 minutes')
on conflict (id) do nothing;

insert into public.goods_receipts(id,organization_id,factory_id,goods_receipt_no,purchase_order_id,received_location_id,released_location_id,received_at,released_at,status,notes) values
 ('94500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','GRN-DEMO-P7-001','93000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000006','44000000-0000-4000-8000-000000000001',now()-interval '8 hours',now()-interval '7 hours 30 minutes','released','Passed incoming quality and released to raw material store')
on conflict (id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,from_location_id,to_location_id,unit_cost,external_reference,notes,occurred_at) values
 ('94600000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005','P7-GRN-REL-001','transfer',50,'44000000-0000-4000-8000-000000000006','44000000-0000-4000-8000-000000000001',12,'GRN-DEMO-P7-001','Release after incoming quality pass',now()-interval '7 hours 30 minutes')
on conflict (id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,occurred_at)
select * from (values
 ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'94600000-0000-4000-8000-000000000001'::uuid,'43000000-0000-4000-8000-000000000005'::uuid,'44000000-0000-4000-8000-000000000006'::uuid,-50::numeric,12::numeric,now()-interval '7 hours 30 minutes'),
 ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'94600000-0000-4000-8000-000000000001'::uuid,'43000000-0000-4000-8000-000000000005'::uuid,'44000000-0000-4000-8000-000000000001'::uuid,50::numeric,12::numeric,now()-interval '7 hours 30 minutes')
) as x(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,occurred_at)
where not exists(select 1 from public.stock_ledger_entries where transaction_id='94600000-0000-4000-8000-000000000001');

insert into public.goods_receipt_lines(id,organization_id,goods_receipt_id,purchase_order_line_id,item_id,quantity_received,unit_cost,lot_batch_no,quality_required,inventory_receive_transaction_id,quality_inspection_id,inventory_release_transaction_id) values
 ('94700000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','94500000-0000-4000-8000-000000000001','93100000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000005',50,12,'GLOVE-LOT-P7-A',true,'94200000-0000-4000-8000-000000000001','94300000-0000-4000-8000-000000000001','94600000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.supplier_invoices(id,organization_id,factory_id,invoice_no,supplier_id,purchase_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status) values
 ('94800000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','SUPINV-DEMO-P7-001','91000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',current_date-1,current_date+14,600,108,708,'partially_paid')
on conflict (id) do nothing;

insert into public.supplier_payments(id,organization_id,factory_id,supplier_invoice_id,payment_no,amount,payment_method,reference_no,paid_at) values
 ('94900000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','94800000-0000-4000-8000-000000000001','SPAY-DEMO-P7-001',400,'bank_transfer','DEMO-UTR-SUP-001',now()-interval '4 hours')
on conflict (id) do nothing;

insert into public.quotations(id,organization_id,factory_id,quotation_no,customer_id,quotation_date,valid_until,currency_code,status,notes) values
 ('95000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','QT-DEMO-P7-001','91000000-0000-4000-8000-000000000003',current_date-2,current_date+5,'INR','converted','Four medical oxygen cylinders for demo customer')
on conflict (id) do nothing;

insert into public.quotation_lines(id,organization_id,quotation_id,item_id,quantity,unit_price,tax_rate,notes) values
 ('95100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006',4,2500,5,'Demo quotation line')
on conflict (id) do nothing;

insert into public.sales_orders(id,organization_id,factory_id,sales_order_no,customer_id,quotation_id,order_date,requested_delivery_date,currency_code,status,dispatch_ready_at,notes) values
 ('95200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','SO-DEMO-P7-001','91000000-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000001',current_date-1,current_date+1,'INR','dispatch_ready',now()-interval '2 hours','Allocated from finished goods and ready for dispatch module')
on conflict (id) do nothing;

insert into public.sales_order_lines(id,organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate,allocated_quantity,dispatched_quantity,notes) values
 ('95300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006',4,2500,5,4,0,'Reserved for dispatch')
on conflict (id) do nothing;

insert into public.sales_allocations(id,organization_id,factory_id,sales_order_id,sales_order_line_id,item_id,location_id,quantity,status) values
 ('95400000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001','95300000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006','44000000-0000-4000-8000-000000000003',4,'allocated')
on conflict (id) do nothing;

insert into public.customer_invoices(id,organization_id,factory_id,invoice_no,customer_id,sales_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status) values
 ('95500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','CINV-DEMO-P7-001','91000000-0000-4000-8000-000000000003','95200000-0000-4000-8000-000000000001',current_date,current_date+20,10000,500,10500,'paid')
on conflict (id) do nothing;

insert into public.customer_payments(id,organization_id,factory_id,customer_invoice_id,payment_no,amount,payment_method,reference_no,paid_at) values
 ('95600000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','95500000-0000-4000-8000-000000000001','CPAY-DEMO-P7-001',10500,'bank_transfer','DEMO-UTR-CUS-001',now()-interval '1 hour')
on conflict (id) do nothing;
