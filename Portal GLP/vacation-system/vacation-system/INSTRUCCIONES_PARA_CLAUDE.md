# Briefing para Claude (Cowork mode)

> **Cómo usar este archivo:** pega este contenido como tu primer mensaje a Claude al abrir el proyecto. Le da todo el contexto en un solo paso.

---

Hola Claude. Voy a continuar un proyecto que mi colega Frank Sapene (Royal Pueblo Investment / LP Development) empezó contigo en su propia sesión. Antes de que te pida nada, por favor:

1. **Lee estos archivos en este orden** para reconstruir el contexto:
   - `PARA_TU_COLEGA.md` (handoff humano)
   - `README.md` (estado técnico)
   - `docs/01-legislacion-panama.md` (reglas legales vacaciones)
   - `docs/02-hallazgo-pasivo-vacaciones.md` (hallazgo crítico)
   - `docs/03-tipos-licencia-panama.md` (catálogo de licencias)

2. **Mira la estructura del repo** con `ls -la` o equivalente para mapear los componentes:
   - `demo.html` es el MVP funcional offline
   - `app/` contiene la estructura Next.js (no instalada)
   - `supabase/migrations/` tiene 4 migraciones SQL en orden
   - `demo/employees-data.json` es la data normalizada
   - Hay 2 archivos Excel: el original y uno con fórmulas vivas

3. **No reinventes cosas ya decididas.** Las decisiones clave fueron:
   - Stack: Next.js 15 App Router + TypeScript + Supabase + Microsoft Entra ID + Tailwind + shadcn/ui + Zod + React Hook Form + TanStack Query + Zustand
   - Multi-tenant por `company_id` con Row-Level Security
   - 14 tipos de licencia codificados según ley panameña
   - Acumulación de vacaciones dinámica desde un `snapshot_date` con tasa 2.7272 días/mes
   - Default password `12345` para todos los usuarios en la demo (esto cambia en producción cuando se conecte a Microsoft 365)
   - Usernames generados con regla "primer nombre . primer apellido" considerando nombres compuestos panameños

4. **Estado actual (mayo 2026):** MVP funcional vertical completo. La demo HTML cubre login, solicitud, aprobación, auditoría, cambio de contraseña, los 14 tipos de licencia, adjuntos en base64, alerta de riesgo legal, multi-empresa, restricciones por rol. La estructura Next.js está esqueleteada pero no instalada ni conectada a Supabase real.

5. **Hallazgo crítico que debes recordar:** 20 empleados del grupo violan el Art. 59 (>60 días acumulados sin notificación a MITRADEL). Total: 1,131 días en exceso. Caso extremo: Ana Julia Urieta con 229 días. Esto requiere acción de RR.HH./Legal antes de ir a producción.

6. **Próximos pasos posibles** (en orden sugerido):
   1. Implementar la sincronización `auth.users → app_users` con trigger PL/pgSQL
   2. Aprobación multinivel configurable
   3. Calendario corporativo con FullCalendar
   4. Notificaciones email
   5. Reportes exportables (XLSX/PDF/Power BI)
   6. Plan operativo de descarga del pasivo de los 20 empleados

7. **Cuando edites código:**
   - Mantén el demo HTML como single-file standalone (no agregues dependencias externas más allá de Tailwind CDN)
   - El demo es el "playground" para probar lógica antes de portarla a Next.js
   - Las reglas legales viven en `app/src/lib/domain/vacation-rules.ts` (puras, testables) y se replican en `demo.html` para el playground
   - Cualquier cambio legal debe quedar documentado en `docs/01-legislacion-panama.md` o `docs/03-tipos-licencia-panama.md`

8. **Cuando me hables, asume que soy:**
   - Otro miembro del equipo de Frank en LP Development
   - No necesariamente desarrollador (probablemente RR.HH. o Operaciones)
   - Necesito que mantengas el sistema funcional y entendible, no que lo refactorices "por elegancia"

9. **Convenciones que el proyecto ya sigue:**
   - Español para todo el código de UI, comentarios de SQL y docs
   - Inglés para nombres de tablas, columnas, types y archivos
   - Cero hardcoded company_id (siempre por contexto del usuario logueado)
   - RLS multi-tenant obligatorio
   - Auditoría inmutable (audit_logs append-only)
   - Adjuntos en producción → Supabase Storage; en demo → base64 en localStorage

10. **Antes de hacer cambios grandes, pregúntame.** No reescribas el demo HTML completo si solo quiero un ajuste cosmético. No cambies el stack sin confirmar. No alteres la legislación documentada sin justificar.

Cuando termines de leer, dame un resumen ejecutivo de 5-7 líneas confirmando que entendiste el estado del proyecto y proponiendo 2-3 alternativas de qué hacer ahora. Luego espera mi instrucción.

Gracias.
