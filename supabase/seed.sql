-- Fictional demo data only. No real person/company data.

insert into public.organizations (
  id, name, code, legal_name, country_code, timezone, currency_code
) values (
  '10000000-0000-4000-8000-000000000001',
  'Aarohan Industrial Gases',
  'AAROHAN',
  'Aarohan Industrial Gases Private Limited',
  'IN',
  'Asia/Kolkata',
  'INR'
) on conflict (id) do nothing;

insert into public.factories (
  id, organization_id, name, code, address_line1, city, state, postal_code, country_code, timezone
) values (
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Aarohan Solapur Plant',
  'SOL-01',
  'MIDC Demo Industrial Area',
  'Solapur',
  'Maharashtra',
  '413006',
  'IN',
  'Asia/Kolkata'
) on conflict (id) do nothing;

insert into public.organization_modules (organization_id, module_key, is_enabled)
select '10000000-0000-4000-8000-000000000001'::uuid, key, true
from public.app_modules
on conflict (organization_id, module_key) do nothing;
