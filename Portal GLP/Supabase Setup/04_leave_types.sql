-- =====================================================================
-- LP Development - Sistema de Vacaciones / Licencias
-- Migration: 0004_leave_types_and_attachments
-- Purpose : Extender el modelo a múltiples tipos de licencia, adjuntos
--           y campos especí­ficos por tipo (parentesco, fecha evento, etc.)
-- =====================================================================

-- ---------------------------------------------------------------------
-- ENUM ampliado: tipos de licencia
-- ---------------------------------------------------------------------
create type leave_type_code as enum (
  'vacation',
  'maternity',
  'paternity',
  'marriage',
  'bereavement_1',     -- padre/madre/cónyuge/hijo/hermano (5d)
  'bereavement_2',     -- abuelos/nietos/suegros/yernos/nueras (3d)
  'bereavement_3',     -- tíos/sobrinos/primos/cuñados (1d)
  'sick_leave',
  'work_injury',
  'medical_appointment',
  'lactation',
  'unpaid_leave',
  'academic',
  'civic_duty'
);

-- ---------------------------------------------------------------------
-- Catálogo: leave_types (configurable por empresa pero con seeds globales)
-- ---------------------------------------------------------------------
create table leave_types (
  id                    uuid primary key default uuid_generate_v4(),
  company_id            uuid not null references companies(id) on delete cascade,
  code                  leave_type_code not null,
  name                  text not null,
  legal_basis           text,                    -- ej: 'Art. 54 Código de Trabajo'
  is_paid               boolean not null default true,
  paid_by               text not null default 'employer',  -- 'employer' | 'css' | 'mixed' | 'none'
  -- Saldo
  has_balance           boolean not null default false,    -- true = tiene saldo; false = ilimitado/por evento
  default_days_per_year numeric(6,2),                       -- ej. 18 para enfermedad
  accrual_days_per_month numeric(6,4),                      -- ej. 2.7272 para vacaciones
  max_days_per_event    int,                                -- ej. 5 para matrimonio, 3 para paternidad
  one_per_employee      boolean not null default false,     -- ej. maternidad/paternidad (por evento, no por año)
  -- Workflow
  auto_approve          boolean not null default false,     -- maternidad, paternidad, riesgos profesionales
  approval_levels       int not null default 1,
  advance_notice_days   int,                                 -- vacaciones: 60
  -- Requisitos
  requires_attachment   boolean not null default false,
  requires_event_date   boolean not null default false,     -- fecha del evento (matrimonio, defunción, nacimiento)
  requires_relationship boolean not null default false,     -- duelo
  -- Display
  icon                  text,
  color                 text,
  sort_order            int not null default 100,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (company_id, code)
);

create index idx_leave_types_company on leave_types (company_id, is_active);

-- ---------------------------------------------------------------------
-- Balances por tipo (sustituye/extiende vacation_balances)
-- ---------------------------------------------------------------------
create table leave_balances (
  id                       uuid primary key default uuid_generate_v4(),
  company_id               uuid not null references companies(id) on delete cascade,
  employee_id              uuid not null references employees(id) on delete cascade,
  leave_type_id            uuid not null references leave_types(id) on delete cascade,
  period_year              int not null,
  baseline_accrued         numeric(8,4) not null default 0,     -- saldo del snapshot inicial
  baseline_used            numeric(8,4) not null default 0,
  extra_used               numeric(8,4) not null default 0,     -- mutaciones por aprobaciones
  snapshot_date            date,                                 -- fecha del snapshot inicial
  accumulation_authorized_at timestamptz,
  notes                    text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (employee_id, leave_type_id, period_year)
);

create index idx_leave_balances_emp_type on leave_balances (employee_id, leave_type_id);

-- ---------------------------------------------------------------------
-- Renombrar vacation_requests → leave_requests con campos extra
-- (En producción se haría con ALTER TABLE; aquí escenificamos como create+drop)
-- ---------------------------------------------------------------------
alter table vacation_requests rename to leave_requests;

-- Agregar columnas faltantes
alter table leave_requests
  add column if not exists leave_type_id      uuid references leave_types(id),
  add column if not exists event_date         date,             -- fecha del evento (defunción, nacimiento, matrimonio)
  add column if not exists relationship       text,             -- parentesco para duelo
  add column if not exists hours_requested    numeric(5,2),     -- para cita médica (por horas)
  add column if not exists attachment_count   int not null default 0,
  add column if not exists css_subsidy_amount numeric(12,2),    -- subsidio CSS aplicable (enfermedad, maternidad)
  add column if not exists employer_diff_amount numeric(12,2);  -- diferencia que cubre el empleador

-- También renombrar approval_steps índices/policies si referencian por nombre antiguo
-- (En producción esto requeriría recrear policies. En el demo solo se simula.)

-- ---------------------------------------------------------------------
-- Adjuntos
-- ---------------------------------------------------------------------
create table leave_attachments (
  id              uuid primary key default uuid_generate_v4(),
  company_id      uuid not null references companies(id) on delete cascade,
  request_id      uuid not null references leave_requests(id) on delete cascade,
  uploaded_by     uuid references app_users(id),
  file_name       text not null,
  file_type       text,
  file_size       int,
  storage_path    text,                          -- ruta en Supabase Storage
  uploaded_at     timestamptz not null default now()
);

create index idx_leave_attachments_request on leave_attachments (request_id);

alter table leave_attachments enable row level security;

create policy "leave_attachments_select"
  on leave_attachments for select
  using (company_id = auth_company_id()
    and (auth_is_hr_or_admin()
      or request_id in (
        select id from leave_requests
        where employee_id in (select id from employees where user_id = auth.uid())
      )
      or request_id in (
        select request_id from approval_steps where approver_id = auth.uid()
      )));

create policy "leave_attachments_insert_self"
  on leave_attachments for insert
  with check (company_id = auth_company_id() and uploaded_by = auth.uid());

-- ---------------------------------------------------------------------
-- Catálogos: seeds por empresa (insert para LP Development a modo de ejemplo)
-- ---------------------------------------------------------------------
-- Función helper para seed
create or replace function seed_leave_types_for_company(p_company_id uuid)
returns void
language plpgsql
as $$
begin
  insert into leave_types (
    company_id, code, name, legal_basis, is_paid, paid_by, has_balance,
    default_days_per_year, accrual_days_per_month, max_days_per_event,
    one_per_employee, auto_approve, approval_levels, advance_notice_days,
    requires_attachment, requires_event_date, requires_relationship,
    icon, color, sort_order
  ) values
    (p_company_id, 'vacation',            'Vacaciones',                'Art. 54 Código de Trabajo', true, 'employer', true, null, 2.7272, null, false, false, 1, 60, false, false, false, '🏖️', 'blue',    1),
    (p_company_id, 'maternity',           'Maternidad',                'Art. 105-107 CT',           true, 'mixed',    true, null, null,   98,  true,  true,  1, null, true,  true,  false, '🤰', 'pink',    2),
    (p_company_id, 'paternity',           'Paternidad',                'Ley 27 de 2017',            true, 'employer', true, null, null,   3,   true,  true,  1, null, true,  true,  false, '👨‍👦','indigo',  3),
    (p_company_id, 'marriage',            'Matrimonio',                'Reglamento interno',        true, 'employer', true, null, null,   5,   true,  false, 1, null, false, true,  false, '💒', 'purple',  4),
    (p_company_id, 'bereavement_1',       'Duelo - Familiar directo',  'Reglamento interno',        true, 'employer', false,null, null,   5,   false, false, 1, null, true,  true,  true,  '🖤', 'slate',   5),
    (p_company_id, 'bereavement_2',       'Duelo - Familiar 2do grado','Reglamento interno',        true, 'employer', false,null, null,   3,   false, false, 1, null, true,  true,  true,  '🖤', 'slate',   6),
    (p_company_id, 'bereavement_3',       'Duelo - Familiar 3er grado','Reglamento interno',        true, 'employer', false,null, null,   1,   false, false, 1, null, true,  true,  true,  '🖤', 'slate',   7),
    (p_company_id, 'sick_leave',          'Enfermedad común',          'Art. CT + Ley CSS',         true, 'mixed',    true, 18,   1.5,    null,false, false, 1, null, true,  false, false, '🤒', 'amber',   8),
    (p_company_id, 'work_injury',         'Riesgos profesionales',     'Ley CSS Riesgos Prof.',     true, 'css',      false,null, null,   null,false, true,  1, null, true,  true,  false, '⚠️', 'red',     9),
    (p_company_id, 'medical_appointment', 'Cita médica',               'Reglamento interno',        true, 'employer', false,null, null,   null,false, false, 1, null, false, false, false, '🩺', 'emerald',10),
    (p_company_id, 'lactation',           'Lactancia',                 'Art. 114 CT',               true, 'employer', false,null, null,   null,false, true,  1, null, false, false, false, '🍼', 'pink',   11),
    (p_company_id, 'unpaid_leave',        'Licencia sin sueldo',       'Reglamento / acuerdo',      false,'none',     false,null, null,   null,false, false, 1, null, false, false, false, '⏸️', 'slate',  12),
    (p_company_id, 'academic',            'Permiso académico',         'Reglamento interno',        true, 'employer', false,null, null,   null,false, false, 1, null, true,  false, false, '🎓', 'cyan',   13),
    (p_company_id, 'civic_duty',          'Deber cívico (jurado)',     'Constitución y C. Electoral',true,'employer', false,null, null,   null,false, true,  1, null, true,  false, false, '⚖️','indigo', 14)
  on conflict (company_id, code) do nothing;
end;
$$;

-- Aplicar seeds para todas las empresas existentes
do $$
declare
  c record;
begin
  for c in select id from companies loop
    perform seed_leave_types_for_company(c.id);
  end loop;
end$$;

-- ---------------------------------------------------------------------
-- Función helper: incrementar días usados de un balance específico
-- ---------------------------------------------------------------------
create or replace function increment_leave_used_days(
  p_employee_id    uuid,
  p_leave_type_id  uuid,
  p_period_year    int,
  p_days           numeric
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  update leave_balances
    set extra_used = extra_used + p_days
    where employee_id = p_employee_id
      and leave_type_id = p_leave_type_id
      and period_year = p_period_year;
end;
$$;

-- ---------------------------------------------------------------------
-- Migración de datos: las vacation_balances pasan a leave_balances tipo vacation
-- ---------------------------------------------------------------------
insert into leave_balances (
  company_id, employee_id, leave_type_id, period_year,
  baseline_accrued, baseline_used, snapshot_date, notes
)
select
  vb.company_id,
  vb.employee_id,
  lt.id,
  vb.period_year,
  vb.accrued_days,
  vb.used_days,
  current_date,
  vb.notes
from vacation_balances vb
join leave_types lt on lt.company_id = vb.company_id and lt.code = 'vacation'
on conflict do nothing;

-- (No se elimina vacation_balances en esta migración para mantener compatibilidad;
--  pero queda deprecated y la app debe leer de leave_balances en adelante.)

-- ---------------------------------------------------------------------
-- Vista útil: balance actual por empleado y tipo
-- ---------------------------------------------------------------------
create or replace view v_employee_leave_balances as
select
  lb.company_id,
  lb.employee_id,
  e.first_name || ' ' || e.last_name as employee_name,
  lt.code as leave_type_code,
  lt.name as leave_type_name,
  lb.period_year,
  lb.baseline_accrued,
  lb.baseline_used,
  lb.extra_used,
  -- Acumulación dinámica: días desde snapshot × tasa mensual / 30.4375
  case when lt.accrual_days_per_month is not null then
    lb.baseline_accrued + ((current_date - lb.snapshot_date) * (lt.accrual_days_per_month / 30.4375))
  else lb.baseline_accrued end as current_accrued,
  lb.baseline_used + lb.extra_used as current_used,
  lt.has_balance
from leave_balances lb
join employees e   on e.id = lb.employee_id
join leave_types lt on lt.id = lb.leave_type_id
where e.status = 'active';

comment on view v_employee_leave_balances is
  'Balance actual recalculado a la fecha (incluye acumulación dinámica desde snapshot).';
