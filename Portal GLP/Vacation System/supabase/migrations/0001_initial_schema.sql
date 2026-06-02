-- =====================================================================
-- LP Development - Sistema de Vacaciones
-- Migration: 0001_initial_schema
-- Purpose : Tablas base, multi-tenant (company_id), tipos, índices
-- Stack   : PostgreSQL 15+ (Supabase)
-- =====================================================================

-- Extensiones requeridas
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =====================================================================
-- ENUMS
-- =====================================================================

create type user_role as enum (
  'employee',
  'manager',
  'hr',
  'admin'
);

create type employee_status as enum (
  'active',
  'on_leave',
  'on_vacation',
  'terminated'
);

create type request_status as enum (
  'draft',
  'pending',
  'approved',
  'rejected',
  'cancelled'
);

create type approval_decision as enum (
  'pending',
  'approved',
  'rejected'
);

create type audit_action as enum (
  'create',
  'update',
  'delete',
  'approve',
  'reject',
  'cancel',
  'login',
  'logout'
);

-- =====================================================================
-- TABLAS
-- =====================================================================

-- Empresas (multi-tenant root)
create table companies (
  id            uuid primary key default uuid_generate_v4(),
  name          text not null,
  legal_name    text,
  tax_id        text,
  country_code  char(2) not null default 'PA',
  timezone      text not null default 'America/Panama',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table companies is 'Tenant root - cada empresa es un tenant aislado por RLS';

-- Usuarios del sistema (vinculados a Microsoft Entra ID via Supabase Auth)
create table app_users (
  id              uuid primary key,                       -- = auth.users.id (Supabase Auth)
  company_id      uuid not null references companies(id) on delete restrict,
  email           text not null,
  full_name       text not null,
  role            user_role not null default 'employee',
  entra_object_id text,                                   -- Microsoft Entra Object ID
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (company_id, email)
);

comment on column app_users.id is 'Coincide con auth.users.id de Supabase Auth';

-- Empleados (puede o no tener cuenta de usuario)
create table employees (
  id               uuid primary key default uuid_generate_v4(),
  company_id       uuid not null references companies(id) on delete restrict,
  user_id          uuid references app_users(id) on delete set null,
  employee_code    text not null,
  first_name       text not null,
  last_name        text not null,
  email            text not null,
  national_id      text,                                  -- cédula panameña
  department       text,
  position         text,
  hire_date        date not null,
  terminated_at    date,
  monthly_salary   numeric(12,2),
  manager_id       uuid references employees(id) on delete set null,
  status           employee_status not null default 'active',
  metadata         jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (company_id, employee_code),
  unique (company_id, email)
);

comment on column employees.manager_id is 'Jefe directo - usado para enrutamiento de aprobaciones';

-- Políticas de vacaciones (configurables por empresa)
create table vacation_policies (
  id                          uuid primary key default uuid_generate_v4(),
  company_id                  uuid not null references companies(id) on delete cascade,
  name                        text not null,
  is_default                  boolean not null default false,
  -- Reglas legales Panamá (configurables, defaults = ley)
  accrual_days_per_month      numeric(6,4) not null default 2.7272,  -- 30/11
  max_accumulated_periods     int not null default 2,
  allow_fraction              boolean not null default false,
  max_fractions               int not null default 2,
  advance_notice_days         int not null default 60,                -- preaviso 2 meses
  payment_lead_days           int not null default 3,                 -- pago 3 días antes
  payment_calc_basis          text not null default 'avg_11m'         -- 'avg_11m' | 'last_base'
                              check (payment_calc_basis in ('avg_11m','last_base')),
  -- Workflow de aprobación
  approval_levels             int not null default 1,                 -- 1=solo jefe, 2=jefe+HR, etc.
  notes                       text,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create unique index uq_vacation_policies_default
  on vacation_policies (company_id)
  where is_default = true;

-- Balance de vacaciones por empleado y período
create table vacation_balances (
  id                          uuid primary key default uuid_generate_v4(),
  company_id                  uuid not null references companies(id) on delete cascade,
  employee_id                 uuid not null references employees(id) on delete cascade,
  period_year                 int not null,                          -- ej. 2026 (período laboral)
  accrued_days                numeric(8,4) not null default 0,
  used_days                   numeric(8,4) not null default 0,
  available_days              numeric(8,4) generated always as (accrued_days - used_days) stored,
  accumulation_authorized_at  timestamptz,                            -- fecha notificación MITRADEL
  notes                       text,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  unique (employee_id, period_year)
);

-- Solicitudes de vacaciones
create table vacation_requests (
  id                  uuid primary key default uuid_generate_v4(),
  company_id          uuid not null references companies(id) on delete cascade,
  employee_id         uuid not null references employees(id) on delete restrict,
  policy_id           uuid not null references vacation_policies(id),
  start_date          date not null,
  end_date            date not null,
  business_days       int not null,                                   -- días hábiles solicitados
  calendar_days       int not null,                                   -- días calendario
  reason              text,
  status              request_status not null default 'draft',
  fraction_index      int not null default 1,                         -- 1 o 2 si fracciona
  fraction_total      int not null default 1,
  short_notice        boolean not null default false,                 -- < 60 días anticipación
  short_notice_ack    boolean not null default false,                 -- acuerdo expreso
  submitted_at        timestamptz,
  decided_at          timestamptz,
  decided_by          uuid references app_users(id),
  decision_notes      text,
  cancelled_at        timestamptz,
  cancelled_by        uuid references app_users(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (end_date >= start_date),
  check (business_days > 0),
  check (fraction_index between 1 and 2),
  check (fraction_total between 1 and 2)
);

create index idx_vacation_requests_employee on vacation_requests (employee_id, status);
create index idx_vacation_requests_company_status on vacation_requests (company_id, status);
create index idx_vacation_requests_dates on vacation_requests (start_date, end_date);

-- Pasos de aprobación (multinivel)
create table approval_steps (
  id            uuid primary key default uuid_generate_v4(),
  company_id    uuid not null references companies(id) on delete cascade,
  request_id    uuid not null references vacation_requests(id) on delete cascade,
  step_order    int not null,
  approver_id   uuid not null references app_users(id),
  decision      approval_decision not null default 'pending',
  decided_at    timestamptz,
  notes         text,
  created_at    timestamptz not null default now(),
  unique (request_id, step_order)
);

create index idx_approval_steps_approver_pending
  on approval_steps (approver_id)
  where decision = 'pending';

-- Auditoría (immutable - solo insert)
create table audit_logs (
  id            uuid primary key default uuid_generate_v4(),
  company_id    uuid not null references companies(id) on delete cascade,
  actor_id      uuid references app_users(id),
  actor_email   text,
  action        audit_action not null,
  entity_type   text not null,                       -- 'vacation_request' | 'employee' | ...
  entity_id     uuid,
  before_state  jsonb,
  after_state   jsonb,
  ip_address    inet,
  user_agent    text,
  created_at    timestamptz not null default now()
);

create index idx_audit_logs_company_created on audit_logs (company_id, created_at desc);
create index idx_audit_logs_entity on audit_logs (entity_type, entity_id);

-- Notificaciones
create table notifications (
  id            uuid primary key default uuid_generate_v4(),
  company_id    uuid not null references companies(id) on delete cascade,
  recipient_id  uuid not null references app_users(id) on delete cascade,
  type          text not null,                       -- 'request_submitted','approved','rejected','reminder'
  title         text not null,
  body          text,
  link_url      text,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);

create index idx_notifications_recipient_unread
  on notifications (recipient_id)
  where read_at is null;

-- Eventos de nómina (placeholder para integración futura)
create table payroll_events (
  id              uuid primary key default uuid_generate_v4(),
  company_id      uuid not null references companies(id) on delete cascade,
  employee_id     uuid not null references employees(id) on delete restrict,
  source_type     text not null,                     -- 'vacation_request' | 'severance'
  source_id       uuid,
  event_type      text not null,                     -- 'vacation_payment' | 'severance_vacation'
  scheduled_at    date not null,
  gross_amount    numeric(12,2),
  calc_basis      text,                              -- 'avg_11m' | 'last_base'
  status          text not null default 'pending',   -- 'pending' | 'processed'
  created_at      timestamptz not null default now()
);

-- =====================================================================
-- TRIGGERS: updated_at
-- =====================================================================

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_companies_updated         before update on companies         for each row execute function set_updated_at();
create trigger trg_app_users_updated         before update on app_users         for each row execute function set_updated_at();
create trigger trg_employees_updated         before update on employees         for each row execute function set_updated_at();
create trigger trg_vacation_policies_updated before update on vacation_policies for each row execute function set_updated_at();
create trigger trg_vacation_balances_updated before update on vacation_balances for each row execute function set_updated_at();
create trigger trg_vacation_requests_updated before update on vacation_requests for each row execute function set_updated_at();
