# Sistema de Gestión de Vacaciones — LP Development

Plataforma SaaS multi-tenant para gestión de vacaciones, alineada al **Código de Trabajo de Panamá** (Arts. 54–61). Stack: **Next.js 15 (App Router) · TypeScript · Supabase · PostgreSQL · Microsoft Entra ID · Tailwind · shadcn/ui · Zod · React Hook Form · TanStack Query · Zustand**.

> **Estado**: MVP vertical funcional. Cubre solicitud → aprobación → auditoría end-to-end. Diseñado para escalar al resto de módulos HR.

---

## Contenido del repositorio

```
.
├── demo.html                          ← DEMO ejecutable (abrir en navegador, sin instalar nada)
├── docs/
│   └── 01-legislacion-panama.md       ← Resumen ley y mapeo a reglas del sistema
├── supabase/
│   ├── migrations/
│   │   ├── 0001_initial_schema.sql    ← Tablas + tipos + índices
│   │   └── 0002_rls_policies.sql      ← Row Level Security multi-tenant
│   └── seeds/seed.sql                  ← Datos de LP Development
└── app/                                ← Proyecto Next.js
    ├── package.json
    ├── tsconfig.json
    ├── .env.example
    └── src/
        ├── middleware.ts                ← Auth guard global
        ├── lib/
        │   ├── supabase/{client,server}.ts
        │   ├── types/domain.ts
        │   ├── schemas/vacation.ts      ← Zod (input validation)
        │   └── domain/vacation-rules.ts ← Reglas de negocio puras (testables)
        ├── modules/
        │   └── vacations/
        │       ├── actions.ts            ← Server Actions
        │       ├── components/vacation-request-form.tsx
        │       └── __tests__/vacation-rules.test.ts
        └── app/
            ├── login/page.tsx            ← Microsoft 365 OAuth
            ├── auth/callback/route.ts
            └── (app)/
                ├── dashboard/page.tsx
                └── vacaciones/nueva/page.tsx
```

---

## 1) Probar la demo ahora (sin instalación)

Abre `demo.html` con doble clic. Verás:

- **Sidebar** y dashboard ejecutivo
- **Cambio de rol** desde el switcher arriba a la derecha (Empleado / Jefe / RR.HH. / Admin)
- **Flujo completo**: solicitar → aprobar/rechazar → auditoría
- **Validaciones legales aplicadas**: 30 días/11 meses, preaviso 60 días, pago 3 días antes, fraccionamiento bloqueado
- Datos persisten en `localStorage`. Botón "Reiniciar datos" en el sidebar.

Recorrido sugerido:
1. Selecciona **Carlos Pérez (Empleado)** → Mis vacaciones → +Nueva solicitud. Solicita 5 días.
2. Cambia a **María González (Jefe)** → Aprobaciones → aprueba la solicitud.
3. Cambia a **Lucía RR.HH.** → Auditoría → ve la bitácora inmutable.

---

## 2) Desplegar el proyecto Next.js

### Pre-requisitos
- Node 20+, pnpm o npm
- Cuenta Supabase (free tier alcanza)
- Tenant Microsoft 365 con permiso para registrar aplicación (Entra ID)

### Paso a paso

```bash
cd app
cp .env.example .env.local
npm install
```

**a) Supabase**
1. Crea un proyecto en https://app.supabase.com
2. Copia `Project URL` → `NEXT_PUBLIC_SUPABASE_URL`
3. Copia `anon public key` → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. Copia `service_role key` → `SUPABASE_SERVICE_ROLE_KEY` (solo backend)
5. Aplica migraciones:
   ```bash
   npx supabase link --project-ref <ref>
   npx supabase db push
   psql <connection-string> < ../supabase/seeds/seed.sql
   ```

**b) Microsoft Entra ID**
1. Azure Portal → **Microsoft Entra ID** → App registrations → New registration
   - Redirect URI: `https://<TU-PROYECTO>.supabase.co/auth/v1/callback`
2. Copia **Application (client) ID** y **Directory (tenant) ID**
3. En **Certificates & secrets** → New client secret. Copia el valor.
4. En **API permissions** → agrega `openid`, `email`, `profile`
5. En Supabase Dashboard → **Authentication → Providers → Azure**:
   - Enable, pega `Application ID`, `Tenant ID`, `Client Secret`
6. Configura `Azure Tenant URL` para limitar a tu tenant: `https://login.microsoftonline.com/<TENANT-ID>/v2.0`

**c) Sincronización usuarios Entra → app_users**
Cuando un usuario se loguea por primera vez, Supabase crea su registro en `auth.users`. Se requiere un trigger (o webhook) que inserte en `public.app_users` con el `company_id` correspondiente. Pendiente implementar — opciones:
- Trigger PL/pgSQL `after insert on auth.users` que mapee por dominio de email (`@lpdevelopment.com` → company LP).
- Webhook a Edge Function que valide y enriquezca.

**d) Correr**
```bash
npm run dev        # http://localhost:3000
npm run typecheck
npm run test       # vitest sobre las reglas de negocio
```

---

## 3) Reglas legales codificadas (resumen)

| # | Regla del Código de Trabajo de Panamá | Implementación |
|---|----------------------------------------|----------------|
| 1 | Art. 54 - 30 días / 11 meses          | `vacation_policies.accrual_days_per_month = 2.7272` |
| 2 | Art. 54 - Pago = 1 mes salario (promedio 11m si hay variables) | `payroll_events.calc_basis` configurable |
| 3 | Art. 54 - Pago 3 días antes            | `payroll_events.scheduled_at = start - 3d` |
| 4 | Art. 55 - Máx 2 fracciones iguales con convención colectiva | `allow_fraction`, `fraction_index`, `fraction_total` |
| 5 | Art. 56 - Preaviso 2 meses             | `advance_notice_days = 60`, flag `short_notice` + acuerdo expreso |
| 6 | Art. 58 - Vacaciones proporcionales al cese | Pendiente trigger `employees.terminated_at` |
| 7 | Art. 59 - Acumulación máx 2 períodos con notificación MITRADEL | `vacation_balances.period_year` + `accumulation_authorized_at` |
| 8 | Art. 60 - Sin sanciones durante vacaciones | Pendiente módulo disciplinario futuro |

Ver detalle en [`docs/01-legislacion-panama.md`](./docs/01-legislacion-panama.md).

---

## 4) Roadmap

### Implementado en MVP
- [x] Schema multi-tenant con RLS
- [x] Solicitud → aprobación 1 nivel → auditoría
- [x] Validaciones cliente (Zod + RHF) y servidor (server actions + reglas puras)
- [x] Microsoft 365 OAuth (estructura)
- [x] Dashboard básico con métricas
- [x] Tests unitarios de reglas de negocio
- [x] Demo HTML standalone

### Pendiente fase 2
- [ ] Aprobación multinivel configurable
- [ ] Calendario corporativo (FullCalendar) con vista mensual/anual
- [ ] Notificaciones email (Resend o SendGrid)
- [ ] Sincronización automática `auth.users → app_users` (trigger PL/pgSQL)
- [ ] Reportes exportables (XLSX, PDF) e integración Power BI
- [ ] Vacaciones colectivas / cierre de oficina
- [ ] Trigger de liquidación al `terminated_at`
- [ ] Onboarding/offboarding de empresas (multi-tenant real)
- [ ] Roles granulares (delegación de aprobación, suplencias)
- [ ] PWA + notificaciones push

### Pendiente fase 3 (resto del sistema HR)
- [ ] Permisos especiales (duelo, matrimonio, paternidad/maternidad)
- [ ] Tiempo extra y bancos de horas
- [ ] Evaluaciones de desempeño
- [ ] Onboarding de empleados (firma digital de contratos)
- [ ] Capacitaciones y certificaciones
- [ ] Nómina (integración con sistema existente)

---

## 5) Decisiones pendientes de confirmar con LP Development

1. ¿Existe **convención colectiva** que permita fraccionamiento? Por defecto **NO**.
2. ¿Cómo se hace hoy la **notificación a MITRADEL** para acumulación? (afecta workflow)
3. ¿Política sobre **puentes y feriados** nacionales?
4. ¿**Vacaciones colectivas** (cierre de oficinas)? Requiere módulo aparte.
5. ¿Empleados con **jornada parcial**? El cálculo del salario base difiere.
6. ¿**Niveles de aprobación**? MVP usa 1 (jefe directo). RR.HH. puede requerir intermediar.

---

## 6) Aviso legal

Esta implementación se basa en la lectura pública del Código de Trabajo de Panamá. **No reemplaza asesoría legal**. LP Development debe validar la configuración de `vacation_policies` con su asesor laboral antes de producción.

---

## Sources

- [Código de Trabajo de Panamá (justia)](https://docs.panama.justia.com/federales/codigos/codigo-de-trabajo.pdf)
- [Código de Trabajo (MITRADEL)](https://www.mitradel.gob.pa/wp-content/uploads/2016/12/c%C3%B3digo-detrabajo.pdf)
- [Laboremia — preguntas frecuentes vacaciones](https://blog.laboremia.com/pa/preguntas-frecuentes-sobre-el-derecho-a-vacaciones)
- [Tiempo Exacto — cálculo de vacaciones](https://www.tiempoexacto.com/post/c%C3%B3mo-calcular-las-vacaciones-en-panam%C3%A1-de-acuerdo-con-el-c%C3%B3digo-de-trabajo)
- [FiniquitoJusto — guía vacaciones 2026](https://finiquitojusto.com/derechos-laborales/guia-vacaciones-anuales-panama-2026/)
