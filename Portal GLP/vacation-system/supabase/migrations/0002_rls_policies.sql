-- =====================================================================
-- LP Development - Sistema de Vacaciones
-- Migration: 0002_rls_policies
-- Purpose : Row Level Security multi-tenant + funciones helper
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helpers: leer el company_id y role del usuario autenticado
-- ---------------------------------------------------------------------

create or replace function auth_company_id() returns uuid
language sql stable security definer set search_path = public, auth as $$
  select company_id from app_users where id = auth.uid();
$$;

create or replace function auth_role() returns user_role
language sql stable security definer set search_path = public, auth as $$
  select role from app_users where id = auth.uid();
$$;

create or replace function auth_is_hr_or_admin() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select role in ('hr','admin') from app_users where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Habilitar RLS en todas las tablas tenant-scoped
-- ---------------------------------------------------------------------

alter table companies          enable row level security;
alter table app_users          enable row level security;
alter table employees          enable row level security;
alter table vacation_policies  enable row level security;
alter table vacation_balances  enable row level security;
alter table vacation_requests  enable row level security;
alter table approval_steps     enable row level security;
alter table audit_logs         enable row level security;
alter table notifications      enable row level security;
alter table payroll_events     enable row level security;

-- ---------------------------------------------------------------------
-- companies: cada usuario solo ve su empresa
-- ---------------------------------------------------------------------
create policy "companies_select_own"
  on companies for select
  using (id = auth_company_id());

create policy "companies_admin_update"
  on companies for update
  using (id = auth_company_id() and auth_role() = 'admin');

-- ---------------------------------------------------------------------
-- app_users: ver usuarios de la misma empresa; HR/admin pueden gestionar
-- ---------------------------------------------------------------------
create policy "app_users_select_same_company"
  on app_users for select
  using (company_id = auth_company_id());

create policy "app_users_hr_admin_write"
  on app_users for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- ---------------------------------------------------------------------
-- employees:
--   - empleados ven su propio registro
--   - managers ven a su equipo (manager_id = self.employee.id)
--   - HR/admin ven todo
-- ---------------------------------------------------------------------
create policy "employees_self_select"
  on employees for select
  using (
    company_id = auth_company_id()
    and (
      auth_is_hr_or_admin()
      or user_id = auth.uid()
      or manager_id in (select id from employees where user_id = auth.uid())
    )
  );

create policy "employees_hr_admin_write"
  on employees for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- ---------------------------------------------------------------------
-- vacation_policies: lectura para todos en la empresa; escritura HR/admin
-- ---------------------------------------------------------------------
create policy "vacation_policies_select_company"
  on vacation_policies for select
  using (company_id = auth_company_id());

create policy "vacation_policies_hr_admin_write"
  on vacation_policies for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- ---------------------------------------------------------------------
-- vacation_balances: empleado ve el suyo; manager ve equipo; HR todo
-- ---------------------------------------------------------------------
create policy "vacation_balances_select"
  on vacation_balances for select
  using (
    company_id = auth_company_id()
    and (
      auth_is_hr_or_admin()
      or employee_id in (select id from employees where user_id = auth.uid())
      or employee_id in (
        select id from employees
        where manager_id in (select id from employees where user_id = auth.uid())
      )
    )
  );

create policy "vacation_balances_hr_write"
  on vacation_balances for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- ---------------------------------------------------------------------
-- vacation_requests:
--   - empleado: ve y crea las suyas
--   - manager: ve las de su equipo; aprueba/rechaza vía approval_steps
--   - HR/admin: full access
-- ---------------------------------------------------------------------
create policy "vacation_requests_select"
  on vacation_requests for select
  using (
    company_id = auth_company_id()
    and (
      auth_is_hr_or_admin()
      or employee_id in (select id from employees where user_id = auth.uid())
      or employee_id in (
        select id from employees
        where manager_id in (select id from employees where user_id = auth.uid())
      )
    )
  );

create policy "vacation_requests_self_insert"
  on vacation_requests for insert
  with check (
    company_id = auth_company_id()
    and employee_id in (select id from employees where user_id = auth.uid())
  );

create policy "vacation_requests_self_update_draft"
  on vacation_requests for update
  using (
    company_id = auth_company_id()
    and employee_id in (select id from employees where user_id = auth.uid())
    and status in ('draft','pending')
  );

create policy "vacation_requests_hr_admin_all"
  on vacation_requests for all
  using (company_id = auth_company_id() and auth_is_hr_or_admin())
  with check (company_id = auth_company_id() and auth_is_hr_or_admin());

-- ---------------------------------------------------------------------
-- approval_steps: aprobadores ven y deciden sus pasos
-- ---------------------------------------------------------------------
create policy "approval_steps_select"
  on approval_steps for select
  using (
    company_id = auth_company_id()
    and (
      auth_is_hr_or_admin()
      or approver_id = auth.uid()
      or request_id in (
        select id from vacation_requests
        where employee_id in (select id from employees where user_id = auth.uid())
      )
    )
  );

create policy "approval_steps_approver_update"
  on approval_steps for update
  using (company_id = auth_company_id() and approver_id = auth.uid());

create policy "approval_steps_system_insert"
  on approval_steps for insert
  with check (company_id = auth_company_id());

-- ---------------------------------------------------------------------
-- audit_logs: solo insert por sistema; lectura HR/admin
-- ---------------------------------------------------------------------
create policy "audit_logs_hr_admin_select"
  on audit_logs for select
  using (company_id = auth_company_id() and auth_is_hr_or_admin());

create policy "audit_logs_authenticated_insert"
  on audit_logs for insert
  with check (company_id = auth_company_id());

-- (No update/delete: la auditoría es inmutable)

-- ---------------------------------------------------------------------
-- notifications: cada quien sus propias notificaciones
-- ---------------------------------------------------------------------
create policy "notifications_self_select"
  on notifications for select
  using (company_id = auth_company_id() and recipient_id = auth.uid());

create policy "notifications_self_update"
  on notifications for update
  using (company_id = auth_company_id() and recipient_id = auth.uid());

create policy "notifications_system_insert"
  on notifications for insert
  with check (company_id = auth_company_id());

-- ---------------------------------------------------------------------
-- payroll_events: HR/admin lectura; sistema escribe
-- ---------------------------------------------------------------------
create policy "payroll_events_hr_admin_select"
  on payroll_events for select
  using (company_id = auth_company_id() and auth_is_hr_or_admin());

create policy "payroll_events_system_insert"
  on payroll_events for insert
  with check (company_id = auth_company_id());
