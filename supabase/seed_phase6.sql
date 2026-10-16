-- Fictional Phase 6 quality demo data. No real person/company data.

insert into public.quality_inspection_plans(id,organization_id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size,effective_from,notes) values
 ('71000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006','47L Medical Oxygen Final Inspection','O2-47L-FINAL','V1','final','fixed',5,current_date-30,'Final release inspection for filled medical oxygen cylinders'),
 ('71000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000004','Oxygen Valve Incoming Inspection','VALVE-INCOMING','V1','incoming','fixed',5,current_date-30,'Incoming valve inspection before production use'),
 ('71000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006','Oxygen Filling In-Process Check','O2-FILL-IPQC','V1','in_process','fixed',3,current_date-30,'In-process fill pressure and leak verification')
on conflict (id) do nothing;

insert into public.quality_plan_checks(id,organization_id,plan_id,sequence_no,parameter_name,check_type,target_numeric,min_numeric,max_numeric,unit_text,expected_boolean,acceptance_text,is_required) values
 ('71100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001',1,'Cylinder visual condition','visual',null,null,null,null,null,'No dents, corrosion or physical damage',true),
 ('71100000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001',2,'Fill pressure','numeric',150,145,155,'bar',null,'145–155 bar at inspection condition',true),
 ('71100000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001',3,'Leak test passed','boolean',null,null,null,null,true,'No detectable leakage',true),
 ('71100000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001',4,'Label and batch marking','visual',null,null,null,null,null,'Readable product, batch and safety marking',true),
 ('71100000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002',1,'Valve body visual condition','visual',null,null,null,null,null,'No cracks, corrosion, burrs or thread damage',true),
 ('71100000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002',2,'Stem dimension','numeric',16,15.5,16.5,'mm',null,'15.5–16.5 mm',true),
 ('71100000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000003',1,'In-process fill pressure','numeric',150,145,155,'bar',null,'145–155 bar',true),
 ('71100000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000003',2,'Leak test passed','boolean',null,null,null,null,true,'No detectable leakage',true)
on conflict (id) do nothing;

insert into public.quality_inspections(id,organization_id,factory_id,inspection_no,plan_id,inspection_type,item_id,production_order_id,production_batch_id,lot_batch_no,sample_size,status,overall_result,inspector_employee_id,started_at,completed_at,remarks) values
 ('72000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','QI-DEMO-FINAL-001','71000000-0000-4000-8000-000000000001','final','43000000-0000-4000-8000-000000000006','53000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000001','LOT-O2-20261015-A',5,'completed','pass','35000000-0000-4000-8000-000000000001',now()-interval '12 minutes',now()-interval '7 minutes','All final inspection parameters acceptable'),
 ('72000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','QI-DEMO-IN-001','71000000-0000-4000-8000-000000000002','incoming','43000000-0000-4000-8000-000000000004',null,null,'VALVE-LOT-DEMO-B',5,'completed','fail','35000000-0000-4000-8000-000000000001',now()-interval '4 hours',now()-interval '3 hours 50 minutes','Two sampled valve bodies show visible thread damage')
on conflict (id) do nothing;

insert into public.quality_inspection_results(id,organization_id,factory_id,inspection_id,plan_check_id,result_status,numeric_value,boolean_value,text_value,remarks,occurred_at) values
 ('72100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','71100000-0000-4000-8000-000000000001','pass',null,null,'Acceptable','No visible damage',now()-interval '10 minutes'),
 ('72100000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','71100000-0000-4000-8000-000000000002','pass',151.2,null,null,'Within final inspection range',now()-interval '9 minutes'),
 ('72100000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','71100000-0000-4000-8000-000000000003','pass',null,true,null,'Leak test clear',now()-interval '8 minutes'),
 ('72100000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','71100000-0000-4000-8000-000000000004','pass',null,null,'Readable','Batch and safety labels verified',now()-interval '7 minutes'),
 ('72100000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002','71100000-0000-4000-8000-000000000005','fail',null,null,'Thread damage','Two samples show thread-edge damage',now()-interval '3 hours 55 minutes'),
 ('72100000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002','71100000-0000-4000-8000-000000000006','pass',16.1,null,null,'Dimension acceptable',now()-interval '3 hours 52 minutes')
on conflict (id) do nothing;

insert into public.quality_ncrs(id,organization_id,factory_id,ncr_no,inspection_id,item_id,severity,category,description,status,disposition,assigned_employee_id,due_date,root_cause,corrective_action) values
 ('73000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','NCR-DEMO-001','72000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000004','high','Incoming material','Valve thread damage found during sampling','investigating','pending','35000000-0000-4000-8000-000000000001',current_date+2,'Supplier packaging/contact damage suspected','Segregate affected lot and verify remaining samples')
on conflict (id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,occurred_at) values
 ('74000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000004','QC-HOLD-DEMO-001','transfer',2,'44000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000004','QI-DEMO-IN-001','Quality quarantine after failed incoming inspection',now()-interval '3 hours 45 minutes')
on conflict (id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at) values
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000004','44000000-0000-4000-8000-000000000001',-2,now()-interval '3 hours 45 minutes'),
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000004','44000000-0000-4000-8000-000000000004',2,now()-interval '3 hours 45 minutes');

insert into public.quality_quarantine_lots(id,organization_id,factory_id,inspection_id,item_id,source_location_id,quarantine_location_id,quantity,lot_batch_no,status,disposition,quarantine_transaction_id,notes,quarantined_at) values
 ('75000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000004','44000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000004',2,'VALVE-LOT-DEMO-B','quarantined','pending','74000000-0000-4000-8000-000000000001','Awaiting NCR disposition',now()-interval '3 hours 45 minutes')
on conflict (id) do nothing;

insert into public.quality_certificates(id,organization_id,factory_id,inspection_id,item_id,certificate_no,lot_batch_no,snapshot,issued_at) values
 ('76000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006','COQ-DEMO-O2-001','LOT-O2-20261015-A',jsonb_build_object('inspection_no','QI-DEMO-FINAL-001','item','Filled Medical Oxygen Cylinder 47L','result','pass','checks',4),now()-interval '5 minutes')
on conflict (id) do nothing;