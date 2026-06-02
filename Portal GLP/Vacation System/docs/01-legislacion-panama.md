# Legislación panameña aplicable al módulo de vacaciones

> **Fuente normativa principal**: Código de Trabajo de Panamá (Decreto de Gabinete 252 de 1971 y reformas).
> **Artículos relevantes**: 54 a 61.
> **Última revisión documental**: mayo 2026.

Este documento resume las reglas legales mínimas que el sistema de vacaciones **debe** respetar para LP Development. Las reglas se traducen luego en políticas configurables a nivel de empresa (`vacation_policies`) y en validaciones del sistema.

---

## 1. Derecho y duración (Art. 54)

- **30 días calendario** de vacaciones remuneradas por cada **11 meses continuos** de trabajo.
- Equivalente práctico: **1 día por cada 11 días trabajados**, o **≈ 2.73 días/mes** para acumulación proporcional.
- El derecho se mantiene aunque el contrato no exija trabajar todas las jornadas u horas (jornada parcial).

**Regla en el sistema**: el balance de vacaciones se acredita mensualmente como `accrual_days_per_month = 30 / 11 ≈ 2.7272`. La política por defecto de LP Development se inicializa con este valor.

---

## 2. Pago de las vacaciones (Art. 54)

- Equivale a **1 mes de salario** cuando se paga mensualmente, o **4 1/3 semanas** cuando se paga semanal.
- Si hay primas, comisiones o variables, se paga el **promedio de los últimos 11 meses** (ordinarios y extraordinarios) **o el último salario base**, lo que resulte **más favorable al trabajador**.
- **Pago anticipado**: las sumas se liquidan y entregan **3 días antes** del inicio del descanso.

**Regla en el sistema**: cuando se aprueba una solicitud, el sistema genera un registro `payroll_event` (placeholder por ahora) con fecha de pago = `inicio_vacaciones - 3 días naturales`. La nómina toma ese evento como input.

---

## 3. Fraccionamiento (Art. 55)

- Las vacaciones solo se pueden **dividir en 2 fracciones iguales** como máximo.
- Requiere: **convención colectiva** que lo permita **y** acuerdo expreso con el trabajador en cada ocasión.

**Regla en el sistema**: una `vacation_request` puede ser de tipo `full` o `fraction`. Si es `fraction`, debe existir una segunda solicitud que complete el período (o quede explícita la otra mitad), y el total no puede superar 2 fracciones por período de 11 meses. La política `vacation_policies.allow_fraction` debe estar en `true` (LP Development definirá si aplica).

---

## 4. Acumulación (Art. 59)

- Acumulables **hasta 2 períodos** mediante acuerdo empleador-trabajador.
- El acuerdo debe **notificarse a la autoridad de trabajo** (MITRADEL).
- La autoridad puede prohibir la acumulación dentro de los 20 días siguientes si la considera lesiva al trabajador.

**Regla en el sistema**:
- `vacation_balances` lleva separados los períodos acumulados (`period_year`, `available_days`, `accumulation_authorized_at`).
- El sistema **bloquea solicitudes** que excedan 2 períodos acumulados salvo que exista `accumulation_authorized_at` registrado.
- Se genera una alerta automática a HR cuando un empleado tiene 1 período sin disfrutar al cumplir el siguiente.

---

## 5. Notificación y preaviso (Art. 56)

- El empleador debe notificar al trabajador el inicio de sus vacaciones con **2 meses de anticipación**.
- En la práctica, esto se invierte cuando el trabajador es quien solicita: la **aprobación final** debería emitirse con al menos 2 meses de antelación, salvo acuerdo expreso.

**Regla en el sistema**: una solicitud aprobada con `start_date - approval_date < 60 días` se marca con flag `short_notice = true` y requiere checkbox de "acuerdo expreso entre las partes" en el formulario de aprobación. No bloquea, pero deja constancia auditable.

---

## 6. Vacaciones proporcionales al cese (Art. 58)

- Si el contrato termina antes de cumplir 11 meses (o antes de gozar las vacaciones causadas), el empleador **debe pagar la parte proporcional** en la liquidación.

**Regla en el sistema**: al desactivar un empleado (`employees.terminated_at`), el sistema calcula `días_proporcionales = meses_trabajados × (30/11)` y genera un `payroll_event` tipo `severance_vacation`.

---

## 7. Protección durante vacaciones (Art. 60)

- **Prohibido**, bajo pena de nulidad, iniciar, adoptar o comunicar al trabajador sanciones o medidas previstas en el Código mientras esté en vacaciones.

**Regla en el sistema**: el módulo de auditoría registra el estado del empleado al momento de cualquier acción HR. Si un empleado está en `vacation_status = 'on_vacation'`, las acciones disciplinarias (futuro módulo) se bloquean.

---

## 8. Prescripción

- Los términos de **caducidad y prescripción se suspenden** durante el goce efectivo de vacaciones o incapacidad.

**Regla en el sistema**: relevante para reclamaciones laborales y módulos futuros; por ahora solo se documenta.

---

## 9. Resumen ejecutivo: matriz de reglas codificadas

| # | Regla legal                        | Campo / lógica del sistema                                  |
|---|------------------------------------|-------------------------------------------------------------|
| 1 | 30 días / 11 meses                 | `vacation_policies.accrual_days_per_month = 2.7272`         |
| 2 | Pago 1 mes salario                 | `payroll_events.gross_amount = monthly_salary` (placeholder)|
| 3 | Pago 3 días antes                  | `payroll_events.scheduled_at = start_date - 3 días`         |
| 4 | Promedio 11 meses si hay variables | `payroll_events.calc_basis = 'avg_11m' \| 'last_base'`      |
| 5 | Máx 2 fracciones iguales           | `vacation_requests.fraction_index ∈ {1,2}`                  |
| 6 | Acumulación máx 2 períodos         | `vacation_balances.period_year` + check al solicitar        |
| 7 | Acumulación notificada a MITRADEL  | `vacation_balances.accumulation_authorized_at`              |
| 8 | Preaviso 2 meses                   | Flag `short_notice` + acuerdo expreso                       |
| 9 | Pago proporcional al cese          | Trigger en `employees.terminated_at`                        |
| 10| Sin sanciones durante vacaciones   | Bloqueo en módulo disciplinario (futuro)                    |

---

## 10. Decisiones pendientes con LP Development

Antes de pasar de MVP a producción se deben confirmar con RRHH / Legal:

1. ¿LP Development tiene convención colectiva que permita fraccionamiento? Si no, dejamos `allow_fraction = false` por defecto.
2. ¿Cómo se gestiona la notificación a MITRADEL hoy? (afecta workflow de acumulación)
3. ¿Política interna sobre puentes y feriados nacionales? (no es ley, pero suele combinarse con vacaciones)
4. ¿Se permiten vacaciones colectivas (cierre de oficina)? Requiere módulo aparte.
5. ¿Política para empleados con jornada parcial o por horas? La ley aplica igual, pero el cálculo del salario base difiere.

---

## Fuentes consultadas

- Código de Trabajo de Panamá (PDF oficial) — https://docs.panama.justia.com/federales/codigos/codigo-de-trabajo.pdf
- MITRADEL — Código de Trabajo — https://www.mitradel.gob.pa/wp-content/uploads/2016/12/c%C3%B3digo-detrabajo.pdf
- Laboremia — 8 preguntas frecuentes sobre vacaciones — https://blog.laboremia.com/pa/preguntas-frecuentes-sobre-el-derecho-a-vacaciones
- Tiempo Exacto — Cómo calcular vacaciones según el Código de Trabajo — https://www.tiempoexacto.com/post/c%C3%B3mo-calcular-las-vacaciones-en-panam%C3%A1-de-acuerdo-con-el-c%C3%B3digo-de-trabajo
- FiniquitoJusto — Guía completa vacaciones 2026 — https://finiquitojusto.com/derechos-laborales/guia-vacaciones-anuales-panama-2026/
- SIJUSA — Art. 59 Acumulación — https://www.sijusa.com/wp-content/uploads/2021/06/Lab_cons_art_59_acumulacion.pdf

> **Nota**: Esta documentación NO reemplaza asesoría legal. LP Development debe validarla con su asesor laboral antes de despliegue a producción.
