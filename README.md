# Tableros Marketing Habi

Hub de dashboards de performance, funnel e inversión de marketing — datos auto-actualizados diariamente desde BigQuery a las 7:00 AM Colombia.

**URL pública**: https://sebastianciendua-habi.github.io/tablero-campanas-habi-co/

## Tableros disponibles

- **[performance-campanas-co/](performance-campanas-co/)** — Performance de campañas paid (Google, Facebook, etc.) Colombia. Funnel + inversión + costos por etapa. Filtros por plataforma, fuente y campaña.

## Cómo agregar un tablero nuevo

1. Crear carpeta nueva al nivel raíz (ej. `nuevo-tablero/`) con 3 archivos:
   - `query.sql` — la query de BigQuery
   - `index.html` — el dashboard
   - `data.json` — placeholder, se sobrescribe automáticamente
2. Agregar **2 steps** en `.github/workflows/update-data.yml`:
   - `Query — nuevo-tablero` (corre la query)
   - `Process — nuevo-tablero` (transforma a JSON compacto)
3. Agregar la carpeta al `git add` del step de commit del workflow.
4. Agregar un `<a class="card">` al `index.html` raíz que linkee al nuevo tablero.

Hay un comentario marcador (`↓↓↓ Agregar más tableros aquí ↓↓↓`) en el workflow que muestra exactamente dónde insertar los steps.

## Auto-update

- **Cron**: cada día a las `13:00 UTC` (7am Colombia / 6am México).
- **Manual**: Actions → Run workflow.
- **Secrets requeridos**:
  - `GCP_CREDENTIALS`: JSON de Application Default Credentials con acceso a BigQuery.
  - `GCP_PROJECT`: `papyrus-data` (proyecto de billing).

Si las credenciales expiran (cambio de password, política de Workspace), regenerar:

```bash
gcloud auth application-default login
cat ~/.config/gcloud/application_default_credentials.json   # copiar y actualizar el secret en GitHub
```

## Estructura del repo

```
.
├── index.html                   # Hub que lista los tableros
├── README.md
├── .github/workflows/update-data.yml
│
└── performance-campanas-co/     # Tablero #1
    ├── index.html
    ├── query.sql
    └── data.json
```
