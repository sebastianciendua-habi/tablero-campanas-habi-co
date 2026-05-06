# Tablero Performance Campañas — Habi Colombia

Dashboard de performance de campañas paid media (Google, Facebook, etc.) con funnel completo + inversión + costos por etapa. Datos auto-actualizados diariamente desde BigQuery.

**URL pública**: https://sebastianciendua-habi.github.io/tablero-campanas-habi-co/

## Qué muestra

- **Funnel ON FECHA**: Impresiones → Clicks → Creados → Calificados → Asignados → Citas → Cierres
- **Costos**: Inversión, CPM, CP Click, CP Lead, CP Calificado, CP Asignado, CP Cita, CP Cierre
- **Tasas**: %CTR, %Click→Lead, %CR, %Tasa Asignación, %Cita, %Cierre
- **Filtros**: Plataforma (Google/Facebook/Otros), Fuente (WEB/Estudio/LeadForms), campaña, granularidad (D/W/M), rango de fechas
- **Gráfica mensual**: comparación de volumen del funnel mes a mes

## Definiciones clave

- **Calificado** = primera entrada a `state_id` 20 ó 63 (`fecha_primer_calificacion` en `tabla_inmuebles_general`)
- **Filtro de Fuente** = sufijo del nombre de la campaña: `lfr`/`leadform` → Lead Forms · `hmt` → Estudio Inmueble · `web` → WEB
- **Plataforma**: Facebook agrupa Facebook + Instagram (ambos Meta)
- **Período**: desde 2024-01-01 hasta hoy

## Auto-update

El workflow `.github/workflows/update-data.yml` corre cada día a las 7am Colombia (cron `0 13 * * *` UTC) y commitea el `data.json` actualizado. También se puede disparar manualmente desde Actions → Run workflow.

### Secrets requeridos

- `GCP_CREDENTIALS`: JSON de Application Default Credentials con acceso a BigQuery (proyectos `papyrus-data` y `sellers-main-prod`)
- `GCP_PROJECT`: `papyrus-data` (proyecto de billing para el job)

## Correr local

```bash
# Requiere bq CLI autenticado y python3
bq query --use_legacy_sql=false --format=json --max_rows=500000 < query.sql > /tmp/raw.json
# (procesar a data.json igual que el workflow)
python3 -m http.server 8765
open http://localhost:8765/
```
