-- FactoryOS Fleet demo review seed.
-- Apply after 06_demo_fleet.sql.

update public.driver_profiles dp
set driver_code = x.driver_code
from (values
  ('DEMO-001','DRV-0001'),
  ('DEMO-002','DRV-0002'),
  ('DEMO-003','DRV-0003'),
  ('DEMO-004','DRV-0004'),
  ('DEMO-005','DRV-0005'),
  ('DEMO-006','DRV-0006'),
  ('DEMO-007','DRV-0007'),
  ('DEMO-008','DRV-0008'),
  ('DEMO-009','DRV-0009'),
  ('DEMO-010','DRV-0010')
) x(employee_code,driver_code),
public.employees e,
public.organizations o
where e.employee_code = x.employee_code
  and e.id = dp.employee_id
  and o.id = e.organization_id
  and o.code = 'DKIM';
