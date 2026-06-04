-- =====================================================================
-- LP Development - Seed data para MVP
-- =====================================================================

-- Empresa LP Development (UUID fijo para que las FK del seed sean estables)
insert into companies (id, name, legal_name, country_code, timezone)
values (
  '00000000-0000-0000-0000-0000000010ed',
  'LP Development',
  'LP Development, S.A.',
  'PA',
  'America/Panama'
) on conflict (id) do nothing;

-- Política por defecto = ley panameña
insert into vacation_policies (
  company_id, name, is_default,
  accrual_days_per_month, max_accumulated_periods,
  allow_fraction, max_fractions,
  advance_notice_days, payment_lead_days, payment_calc_basis,
  approval_levels
) values (
  '00000000-0000-0000-0000-0000000010ed',
  'Política estándar Panamá (Art. 54)',
  true,
  2.7272, 2,
  false, 2,
  60, 3, 'avg_11m',
  1
) on conflict do nothing;

-- Empleados demo
-- (Nota: en producción los user_id provienen de Microsoft Entra ID via Supabase Auth)
insert into employees (
  company_id, employee_code, first_name, last_name, email,
  national_id, department, position, hire_date, monthly_salary, status
) values
  ('00000000-0000-0000-0000-0000000010ed','EMP-001','Frank','Sapene','frank.sapene@lpdevelopment.com',
   '8-123-456','Gerencia General','Director de Operaciones','2024-01-15',5000.00,'active'),
  ('00000000-0000-0000-0000-0000000010ed','EMP-002','María','González','maria.gonzalez@lpdevelopment.com',
   '8-234-567','Construcción','Jefe de Proyecto','2023-06-01',2800.00,'active'),
  ('00000000-0000-0000-0000-0000000010ed','EMP-003','Carlos','Pérez','carlos.perez@lpdevelopment.com',
   '8-345-678','Construcción','Supervisor de Obra','2024-03-10',1800.00,'active'),
  ('00000000-0000-0000-0000-0000000010ed','EMP-004','Ana','Rodríguez','ana.rodriguez@lpdevelopment.com',
   '8-456-789','Administración','Asistente Administrativo','2025-02-01',1200.00,'active')
on conflict (company_id, employee_code) do nothing;

-- Jerarquía: María es jefe de Carlos; Frank es jefe de María y Ana
update employees set manager_id = (select id from employees where employee_code = 'EMP-001' and company_id = '00000000-0000-0000-0000-0000000010ed')
  where employee_code in ('EMP-002','EMP-004') and company_id = '00000000-0000-0000-0000-0000000010ed';

update employees set manager_id = (select id from employees where employee_code = 'EMP-002' and company_id = '00000000-0000-0000-0000-0000000010ed')
  where employee_code = 'EMP-003' and company_id = '00000000-0000-0000-0000-0000000010ed';

-- Balances iniciales (período 2026)
insert into vacation_balances (company_id, employee_id, period_year, accrued_days, used_days)
select
  e.company_id,
  e.id,
  2026,
  least(round(extract(month from age(current_date, e.hire_date))::numeric * 2.7272, 2), 30),
  0
from employees e
where e.company_id = '00000000-0000-0000-0000-0000000010ed'
