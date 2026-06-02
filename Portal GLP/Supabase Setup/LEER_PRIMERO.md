# Configuración Supabase — Vacation System GLP

## Ejecutar en este orden exacto en el SQL Editor de Supabase

Ve a **SQL Editor** en el menú izquierdo de Supabase y ejecuta cada archivo en orden.
Copia el contenido completo de cada archivo, pégalo y haz clic en **Run**.

---

### Paso 1 → `01_schema.sql`
Crea todas las tablas principales (empleados, solicitudes, aprobaciones, auditoría).

### Paso 2 → `02_rls_policies.sql`
Configura la seguridad por filas (Row Level Security) — controla quién ve qué datos.

### Paso 3 → `03_projects_extras.sql`
Agrega proyectos y campos adicionales.

### Paso 4 → `04_leave_types.sql`
Carga los 14 tipos de licencia según la ley panameña.

### Paso 5 → `05_usuarios.sql`
Carga los 214 usuarios (212 colaboradores + admin + personal RRHH).

---

## Después de ejecutar los 5 archivos

1. Ve a **Settings → API** en el menú izquierdo
2. Copia:
   - **Project URL** → algo como `https://abcdef.supabase.co`
   - **anon public** key → cadena larga que empieza con `eyJ...`
3. Pásaselas a Claude → él las inserta en el sistema de vacaciones y listo

---

## Credenciales de acceso al sistema (una vez conectado)

| Usuario | Contraseña | Rol |
|---|---|---|
| admin | glp2024 | Administrador |
| asistente.rrhh | GLP2026 | Administrador |
| berta.navarro | 12345 | Administrador |
| francisco.sapene | 12345 | Administrador |
| daniel.chavarria | 12345 | Administrador |
| primernombre.primerapellido | 12345 | Colaborador |
