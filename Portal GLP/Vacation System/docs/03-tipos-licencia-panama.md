# Catálogo de tipos de licencia – Panamá

> **Fuentes**: Código de Trabajo de Panamá (Decreto de Gabinete 252/1971), Ley 27 de 2017 (paternidad), Ley Orgánica de la Caja de Seguro Social, reglamentos internos de la administración pública y prácticas comunes del sector privado.
> **Última revisión**: mayo 2026.

Este documento define el catálogo de licencias soportadas por el sistema, su base legal, duración, requisitos y comportamiento esperado.

---

## Matriz consolidada

| # | Tipo | Código sistema | Base legal | Duración | Pagado por | Adjunto |
|---|------|---------------|-----------|----------|-----------|---------|
| 1 | Vacaciones | `vacation` | Art. 54 CT | 30 días/11 meses | Empleador | – |
| 2 | Maternidad | `maternity` | Art. 105-107 CT | 14 semanas (6 pre + 8 post) | CSS + diferencia empleador | Certificado médico |
| 3 | Paternidad | `paternity` | Ley 27 de 2017 | 3 días hábiles | Empleador | Cert. de nacimiento |
| 4 | Matrimonio | `marriage` | Reglamento interno / acuerdo | Hasta 5 días hábiles | Empleador (depende empresa) | Acta de matrimonio |
| 5 | Duelo grado 1 (padre, madre, cónyuge, hijos, hermanos) | `bereavement_1` | Reglamentos | Hasta 5 días hábiles | Empleador | Acta defunción + parentesco |
| 6 | Duelo grado 2 (abuelos, nietos, suegros, yernos, nueras) | `bereavement_2` | Reglamentos | Hasta 3 días hábiles | Empleador | Acta defunción + parentesco |
| 7 | Duelo grado 3 (tíos, sobrinos, primos, cuñados) | `bereavement_3` | Reglamentos | Hasta 1 día hábil | Empleador | Acta defunción + parentesco |
| 8 | Enfermedad común | `sick_leave` | Art. CT + Ley CSS | 18 días/año (sector privado, acumula hasta 36); luego subsidio CSS hasta 26 sem (extensible a 1 año) | Empleador días 1-3 / CSS desde día 4 (70%) | Certificado médico CSS |
| 9 | Accidente / Riesgos profesionales | `work_injury` | Ley CSS Riesgos Profesionales | Mientras dure la incapacidad | CSS al 100% | Reporte de accidente |
| 10 | Cita médica | `medical_appointment` | Reglamentos | Por jornada parcial | Empleador | Comprobante de cita |
| 11 | Lactancia | `lactation` | Art. 114 CT | 15 min cada 2 h o 30 min ×2 diario, hasta 12 meses post-parto | Empleador (tiempo efectivo) | – |
| 12 | Licencia sin sueldo | `unpaid_leave` | Reglamentos | Variable, sujeta a acuerdo | No remunerado | Solicitud justificada |
| 13 | Permiso académico | `academic` | Reglamentos | Hasta 6 h/sem (compensables 3m), o sin sueldo si > 30 días | Empleador (con compensación) | Constancia académica |
| 14 | Deber cívico (jurado, votación) | `civic_duty` | Constitución / Código Electoral | Mientras dure el deber | Empleador | Citatorio oficial |

---

## Detalle por tipo

### 1. Vacaciones (`vacation`)
**Base legal**: Art. 54 del Código de Trabajo de Panamá.

- **Acumulación**: 30 días por cada 11 meses continuos de trabajo (≈2.7272 días/mes).
- **Preaviso**: 60 días (Art. 56).
- **Fraccionamiento**: máx 2 fracciones iguales, requiere convención colectiva (Art. 55).
- **Acumulación máxima**: 2 períodos con notificación a MITRADEL (Art. 59).
- **Pago**: 3 días antes del inicio (Art. 54).

> Implementación detallada en `docs/01-legislacion-panama.md`.

---

### 2. Maternidad (`maternity`)
**Base legal**: Art. 105-107 del Código de Trabajo.

- **Duración**: 14 semanas mínimo (6 antes del parto + 8 después). Si se retrasa el parto, se mantienen las 8 posteriores.
- **Pago**: Subsidio de la CSS basado en sueldo; el empleador cubre la diferencia con la retribución habitual.
- **Requisitos**:
  - Certificado médico que indique fecha probable de parto.
  - Inicio: 6 semanas antes de la fecha probable.
- **Fuero maternal**: prohibición de despedir a la trabajadora durante el embarazo y hasta 1 año después del parto sin justa causa autorizada por el juez.

**Reglas del sistema**:
- Saldo = 98 días (14 sem × 7) por evento.
- Solo aplica una vez por gestación.
- Campos requeridos: `fecha_probable_parto`, `certificado_medico` (adjunto).

---

### 3. Paternidad (`paternity`)
**Base legal**: Ley 27 de 23 de mayo de 2017.

- **Duración**: 3 días hábiles remunerados, contados desde el nacimiento.
- **No es discrecional**: deben tomarse inmediatamente al nacimiento.
- **Restricción**: el padre no podrá realizar labores para otro empleador durante el período.
- **Adicional**: si tiene derecho a vacaciones, el empleador no podrá negar 15 días de vacaciones complementarios.

**Reglas del sistema**:
- Saldo = 3 días hábiles por evento.
- Solo aplica una vez por nacimiento.
- Campos requeridos: `fecha_nacimiento_hijo`, `certificado_nacimiento` (adjunto).

---

### 4. Matrimonio (`marriage`)
**Base**: Reglamentos internos o convenio colectivo (no en Código de Trabajo del sector privado).

- **Duración**: Hasta 5 días hábiles.
- Pagado a discreción de la empresa (estándar en sector público y empresas con políticas formales).

**Reglas del sistema**:
- Saldo = 5 días hábiles por evento.
- Solo una vez por matrimonio.
- Campos requeridos: `fecha_matrimonio`, `acta_matrimonio` (adjunto opcional).

---

### 5-7. Duelo (`bereavement_1/2/3`)
**Base**: Reglamentos internos y prácticas comunes.

| Grado | Parentesco | Días hábiles |
|-------|-----------|--------------|
| 1 | Padre, madre, cónyuge, hijo(a), hermano(a) | 5 |
| 2 | Abuelos, nietos, suegros, yernos, nueras | 3 |
| 3 | Tíos, sobrinos, primos, cuñados | 1 |

- En casos de traslado a lugar distante, se pueden extender hasta 3 días adicionales (sector público).

**Reglas del sistema**:
- El empleado selecciona el **parentesco** y el sistema asigna el grado y los días.
- Adjunto: acta de defunción.
- Campos requeridos: `fecha_defuncion`, `parentesco`, `acta_defuncion` (adjunto).

---

### 8. Enfermedad común (`sick_leave`)
**Base**: Código de Trabajo + Ley Orgánica CSS.

- **Fondo de incapacidad**: el trabajador acumula 12 horas por cada 26 días trabajados = 144 horas/año. Sector privado: hasta **18 días/año**, acumulando hasta **36 días**.
- **Pago días 1-3**: empleador.
- **Pago desde día 4**: CSS, 70% del salario promedio de los últimos 2 meses de cotización. Máximo 26 semanas por misma enfermedad (extensible a 1 año en casos justificados).
- **Requisito de cotización**: 6 meses cotizados en los últimos 9 meses calendario.

**Reglas del sistema**:
- Saldo dinámico: el empleado acumula a la misma tasa (0.0493 días/día calendario trabajado).
- Marcador visual cuando los días tomados superan 18 en el año (entra subsidio CSS).
- Campos requeridos: `certificado_medico` (adjunto obligatorio).

---

### 9. Riesgos profesionales / Accidente de trabajo (`work_injury`)
**Base**: Ley Orgánica de la Caja de Seguro Social - Programa de Riesgos Profesionales.

- **Duración**: mientras dure la incapacidad.
- **Pago**: 100% del salario por la CSS.
- **Diferencia con enfermedad común**: el origen es laboral; cobertura total y procedimiento distinto.

**Reglas del sistema**:
- Sin límite de días.
- Campos requeridos: `fecha_accidente`, `reporte_accidente` (adjunto), `lugar_accidente`.

---

### 10. Cita médica (`medical_appointment`)
**Base**: Reglamentos internos / práctica establecida.

- **Duración**: por jornada parcial (horas necesarias para acudir).
- **Cobertura**: cita propia o de hijos menores de 2 años.
- **Pagado**: sí, con justificación.

**Reglas del sistema**:
- Permite duración por horas (no días).
- Campos: `hora_cita`, `tipo_cita` (propio/hijo menor), `comprobante` (adjunto opcional).

---

### 11. Lactancia (`lactation`)
**Base**: Art. 114 del Código de Trabajo.

- **Duración por día**: 15 minutos cada 2 horas O 30 minutos × 2 al día.
- **Período**: hasta los 12 meses de edad del bebé.
- **Pagado**: cuenta como tiempo efectivo de trabajo.

**Reglas del sistema**:
- Más que solicitudes puntuales, es una **autorización continua** asociada al empleado.
- Se activa al regresar de licencia de maternidad y dura 12 meses.
- En MVP solo se registra como flag del empleado (sin solicitudes individuales).

---

### 12. Licencia sin sueldo (`unpaid_leave`)
**Base**: Reglamentos / acuerdo entre partes.

- **Duración**: variable, sujeta a aprobación.
- **Pago**: ninguno.
- **Usos comunes**: estudios largos, asuntos personales prolongados.

**Reglas del sistema**:
- Sin límite predefinido.
- Justificación obligatoria.
- No descuenta de balance pagado (es separado).

---

### 13. Permiso académico (`academic`)
**Base**: Reglamentos públicos / acuerdos.

- **Hasta 6 horas/semana** compensables en 3 meses.
- **> 30 días**: pasa a licencia sin sueldo.
- Aplica a estudiantes universitarios y docentes.

**Reglas del sistema**:
- Campos: `institución`, `programa`, `constancia` (adjunto).
- Si > 30 días → sugerir cambio a `unpaid_leave`.

---

### 14. Deber cívico (`civic_duty`)
**Base**: Constitución Política y Código Electoral.

- **Duración**: mientras dure el deber (jurado, día electoral, etc.).
- **Pagado**: sí.

**Reglas del sistema**:
- Adjunto obligatorio: citatorio oficial.

---

## Reglas comunes a todos los tipos

1. **Workflow de aprobación**: por defecto un nivel (jefe directo). Algunos tipos (maternidad, paternidad, riesgos profesionales) son **automáticamente aprobados** por ser derechos legales irrevocables, pero requieren registro y notificación.
2. **Auditoría**: cada solicitud genera audit_logs inmutables.
3. **Notificación**: cualquier cambio de estado dispara notificación al empleado.
4. **Adjuntos**: se almacenan vinculados a la solicitud (en producción: Supabase Storage; en demo: base64 en localStorage).
5. **Validaciones del sistema**: balance disponible, fechas razonables, adjuntos cuando son obligatorios.

---

## Decisiones pendientes con LP Development

1. ¿Las empresas del grupo tienen reglamento interno con días específicos para matrimonio y duelo? Defaults usan estándar del sector público.
2. ¿Existe política de **lactancia** explícita? En MVP solo se registra como flag, sin solicitudes individuales.
3. ¿Cómo se procesará el **pago compartido CSS + empleador** (maternidad, enfermedad)? Por ahora solo se registra; integración con nómina queda para fase 2.
4. ¿Habrá tipos adicionales corporativos? (por ejemplo: día del cumpleaños, voluntariado, work from home autorizado).

---

## Fuentes

- [Código de Trabajo de Panamá (justia)](https://docs.panama.justia.com/federales/codigos/codigo-de-trabajo.pdf)
- [Guía maternidad y paternidad 2026 - FiniquitoJusto](https://finiquitojusto.com/derechos-laborales/guia-licencia-maternidad-paternidad-panama-2026/)
- [Ley 27 de 2017 - Licencia de paternidad (Morgan & Morgan)](https://morimor.com/es/espanol-nueva-ley-que-crea-la-licencia-de-paternidad-en-panama/)
- [MITRADEL - Licencia de paternidad](https://www.mitradel.gob.pa/ejecutivo-sanciono-ley-licencia-paternidad/)
- [CSS - Subsidio por enfermedad común](https://w3.css.gob.pa/subsidio-por-enfermedad-comun/)
- [PanaJobs - Permiso por lactancia Art. 114](https://panajobs.com/detalles-del-permiso-para-lactancia-segun-art-114-del-codigo-de-trabajo/)
- [TopTrabajos - Licencia por luto](https://www.toptrabajos.com/blog/carrera/licencia-por-luto/)
- [PanaJobs - Días por duelo familiar](https://panajobs.com/cuantos-dias-se-deben-dar-por-duelo-familiar/)
- [Fuero maternal en Panamá - Legal Solutions Panama](https://legalsolutionspanama.com/blog/fuero-maternal-panama-licencia-maternidad-pago/)

> **Nota**: este catálogo refleja la lectura pública de la legislación panameña y prácticas comunes. LP Development debe validar con asesor laboral antes de despliegue a producción.
