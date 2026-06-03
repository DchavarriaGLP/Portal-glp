-- =====================================================================
-- LP Development - Sistema de Vacaciones
-- Migration: 0003_projects_and_extras
-- Purpose : Tabla projects (jerarquía empresa→proyecto→empleado) y
--           campos adicionales detectados en la base inicial.
-- =====================================================================

-- Proyectos (una empresa puede tener N proyectos)
create table if not exists projects (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid not null references companies(id) on delete cascade,
  code         text,
  name         text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (company_id, name)
);

create index if not exists idx_projects_company on projects (company_id);

create trigger trg_projects_updated before update on projects
  for each row execute function set_updated_at();

-- Campos extra de employees detectados en la base inicial
alter table employees
  add column if not exists project_id uuid references projects(id) on delete set null,
  add column if not exists preferred_vacation_month text;

create index if not exists idx_employees_project on employees (project_id);

-- =====================================================================
-- RLS sobre projects
-- =====================================================================
alter table projects enable row level security;

create policy "projects_select_same_company"
  on projects for select
  using (company_id = auth_company_id());

create policy "projects_hr_admin_write"
  on projects for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- =====================================================================
-- Función RPC para incrementar días usados (referenciada en actions.ts)
-- =====================================================================
create or replace function increment_used_days(
  p_employee_id uuid,
  p_period_year int,
  p_days numeric
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update vacation_balances
    set used_days = used_days + p_days
    where employee_id = p_employee_id
      and period_year = p_period_year;
end;
$$;

-- =====================================================================
-- Vista útil para reportes ejecutivos: empleados con riesgo legal
-- =====================================================================
create or replace view v_legal_risk_balances as
select
  c.name as company_name,
  p.name as project_name,
  e.id as employee_id,
  e.employee_code,
  e.first_name || ' ' || e.last_name as full_name,
  e.position,
  e.hire_date,
  extract(year from age(current_date, e.hire_date))::numeric as antiguedad_anios,
  b.period_year,
  b.accrued_days,
  b.used_days,
  b.available_days,
  case
    when b.available_days > 60 then 'CRITICO_ART_59'  -- > 2 períodos acumulados sin notificar
    when b.available_days > 30 then 'WARNING_1_PERIODO_VENCIDO'
    when b.available_days < 0  then 'SOBREGIRO'
    else 'OK'
  end as risk_flag
from vacation_balances b
join employees e on e.id = b.employee_id
join companies c on c.id = e.company_id
left join projects p on p.id = e.project_id
where e.status = 'active';

comment on view v_legal_risk_balances is
  'Reporte ejecutivo: empleados con riesgo legal por acumulación de vacaciones (Art. 59 - máx 2 períodos sin notificación a MITRADEL).';
