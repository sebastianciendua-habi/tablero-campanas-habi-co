-- =====================================================================
-- Tablero Performance Campañas Colombia
-- Funnel ON FECHA + Spend ON FECHA por (día, plataforma, campaña, fuente).
--
-- Output: dos tipos de filas distinguidas por columna `tipo`
--   tipo='F' → fila de funnel (sin spend), grain (día, fuente, plataforma, campaña)
--   tipo='S' → fila de spend (sin fuente),  grain (día, plataforma, campaña)
-- El frontend cruza ambas según los filtros sin double-counting.
--
-- Calificados = `fecha_primer_calificacion` de tabla_inmuebles_general,
-- que ya implementa la convención Habi (primera entrada a estado 20 ó 63).
-- Fuentes incluidas: 3 (WEB), 7 (Estudio Inmueble), 47 (lead_forms).
-- Período: desde 2024-01-01 hasta CURRENT_DATE() (excluyente).
-- =====================================================================

WITH utm_map AS (
  SELECT
    LOWER(TRIM(campana_mercadeo_original)) AS key_campaign_leads,
    LOWER(TRIM(mkt_campaign_name))         AS key_campaign_spend,
    mkt_channel_big,
    mkt_channel_medium,
    mkt_channel_small,
    mkt_media,
    mkt_platform
  FROM `sellers-main-prod.bi_co.registro_unico_utm_mkt_colombia`
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(campana_mercadeo_original)),
                 LOWER(TRIM(mkt_campaign_name))
    ORDER BY mkt_campaign_name
  ) = 1
),

base_leads AS (
  SELECT
    g.nid,
    g.negocio_id,
    g.fuente_id,
    CAST(g.fecha_creacion              AS DATE) AS f_creado,
    CAST(g.fecha_primer_calificacion   AS DATE) AS f_calificado,
    CAST(g.fecha_cita_agendada         AS DATE) AS f_cita,
    CAST(g.fecha_cierre                AS DATE) AS f_cierre,
    CAST(asi.dia                       AS DATE) AS f_asignado,
    g.campana_mercadeo                          AS campana_mercadeo,
    LOWER(TRIM(g.campana_mercadeo))             AS campana_key,
    CASE
      WHEN LOWER(u.mkt_platform) IN ('facebook','instagram')        THEN 'Facebook'
      WHEN LOWER(u.mkt_platform) = 'tiktok'                         THEN 'TikTok'
      WHEN LOWER(u.mkt_platform) = 'google'                         THEN 'Google'
      WHEN LOWER(u.mkt_platform) = 'bing'                           THEN 'Bing'
      WHEN g.campana_mercadeo IS NULL OR TRIM(g.campana_mercadeo)='' THEN 'Directo'
      WHEN u.mkt_platform IS NULL OR u.mkt_platform = ''            THEN 'Otros'
      ELSE u.mkt_platform
    END                                                                    AS mkt_platform,
    COALESCE(u.mkt_channel_big,    'Otros')                                AS ch_big,
    COALESCE(u.mkt_channel_medium, NULLIF(g.campana_mercadeo,''), 'Otros') AS ch_medium,
    COALESCE(u.mkt_channel_small,  NULLIF(g.campana_mercadeo,''), 'Otros') AS ch_small
  FROM `papyrus-data.habi_wh_bi.tabla_inmuebles_general` g
  LEFT JOIN `papyrus-master.sellers_data_mart.sellers_leads_asignados_marketing_wbr_mart` asi
    ON g.nid = asi.nid
  LEFT JOIN utm_map u
    ON LOWER(TRIM(g.campana_mercadeo)) = u.key_campaign_leads
  WHERE CAST(g.fecha_creacion AS DATE) >= DATE '2024-01-01'
    AND CAST(g.fecha_creacion AS DATE) <  CURRENT_DATE()
    AND g.fuente_id IN (3, 7, 47)
    AND g.nid IS NOT NULL
),

events_long AS (
  SELECT fuente_id, mkt_platform, ch_big, ch_medium, ch_small, campana_mercadeo, campana_key,
         f_creado AS event_date, 'creados' AS etapa, nid
  FROM base_leads WHERE f_creado IS NOT NULL
  UNION ALL
  SELECT fuente_id, mkt_platform, ch_big, ch_medium, ch_small, campana_mercadeo, campana_key,
         f_calificado, 'calificados', nid
  FROM base_leads WHERE f_calificado IS NOT NULL
  UNION ALL
  SELECT fuente_id, mkt_platform, ch_big, ch_medium, ch_small, campana_mercadeo, campana_key,
         f_asignado, 'asignados', nid
  FROM base_leads WHERE f_asignado IS NOT NULL
  UNION ALL
  SELECT fuente_id, mkt_platform, ch_big, ch_medium, ch_small, campana_mercadeo, campana_key,
         f_cita, 'cita', nid
  FROM base_leads WHERE f_cita IS NOT NULL
  UNION ALL
  SELECT fuente_id, mkt_platform, ch_big, ch_medium, ch_small, campana_mercadeo, campana_key,
         f_cierre, 'cerrados', nid
  FROM base_leads WHERE f_cierre IS NOT NULL
),

funnel_on_date AS (
  SELECT
    event_date AS dia,
    fuente_id,
    mkt_platform,
    ch_big, ch_medium, ch_small,
    campana_mercadeo,
    SUM(CASE WHEN etapa='creados'     THEN 1 ELSE 0 END) AS creados,
    SUM(CASE WHEN etapa='calificados' THEN 1 ELSE 0 END) AS calificados,
    SUM(CASE WHEN etapa='asignados'   THEN 1 ELSE 0 END) AS asignados,
    SUM(CASE WHEN etapa='cita'        THEN 1 ELSE 0 END) AS citas,
    SUM(CASE WHEN etapa='cerrados'    THEN 1 ELSE 0 END) AS cierres
  FROM (
    SELECT DISTINCT event_date, fuente_id, mkt_platform, ch_big, ch_medium, ch_small,
                    campana_mercadeo, etapa, nid
    FROM events_long
  )
  GROUP BY 1,2,3,4,5,6,7
),

base_spend AS (
  SELECT
    CAST(i.date AS DATE) AS dia,
    CASE
      WHEN LOWER(u.mkt_platform) IN ('facebook','instagram') THEN 'Facebook'
      WHEN LOWER(u.mkt_platform) = 'tiktok'                  THEN 'TikTok'
      WHEN LOWER(u.mkt_platform) = 'google'                  THEN 'Google'
      WHEN LOWER(u.mkt_platform) = 'bing'                    THEN 'Bing'
      WHEN u.mkt_platform IS NULL OR u.mkt_platform = ''     THEN 'Otros'
      ELSE u.mkt_platform
    END                                                                    AS mkt_platform,
    COALESCE(u.mkt_channel_big,    'Otros')                              AS ch_big,
    COALESCE(u.mkt_channel_medium, NULLIF(i.campana_original,''), 'Otros') AS ch_medium,
    COALESCE(u.mkt_channel_small,  NULLIF(i.campana_original,''), 'Otros') AS ch_small,
    i.campana_original AS campana_mercadeo,
    SUM(i.spend)          AS spend,
    SUM(i.clicks)         AS clicks_link,
    SUM(i.clicks_totales) AS clicks_totales,
    SUM(i.impressions)    AS impressions
  FROM `papyrus-data.habi_wh_bi.resumen_inversiones_mkt_co` i
  LEFT JOIN utm_map u
    ON LOWER(TRIM(i.campana_original)) = u.key_campaign_spend
  WHERE CAST(i.date AS DATE) >= DATE '2024-01-01'
    AND CAST(i.date AS DATE) <  CURRENT_DATE()
  GROUP BY 1,2,3,4,5,6
)

-- ── Filas de funnel (una por día × fuente × plataforma × campaña)
SELECT
  'F' AS tipo,
  CAST(dia AS STRING)        AS dia,
  CAST(fuente_id AS INT64)   AS fuente_id,
  mkt_platform               AS plataforma,
  ch_big, ch_medium, ch_small,
  campana_mercadeo           AS campana,
  CAST(creados     AS INT64) AS creados,
  CAST(calificados AS INT64) AS calificados,
  CAST(asignados   AS INT64) AS asignados,
  CAST(citas       AS INT64) AS citas,
  CAST(cierres     AS INT64) AS cierres,
  CAST(0 AS FLOAT64) AS spend,
  CAST(0 AS INT64)   AS clicks_link,
  CAST(0 AS INT64)   AS clicks_totales,
  CAST(0 AS INT64)   AS impressions
FROM funnel_on_date

UNION ALL

-- ── Filas de spend (una por día × plataforma × campaña, sin fuente)
SELECT
  'S' AS tipo,
  CAST(dia AS STRING)            AS dia,
  CAST(NULL AS INT64)            AS fuente_id,
  mkt_platform                   AS plataforma,
  ch_big, ch_medium, ch_small,
  campana_mercadeo               AS campana,
  0 AS creados, 0 AS calificados, 0 AS asignados, 0 AS citas, 0 AS cierres,
  CAST(spend          AS FLOAT64) AS spend,
  CAST(clicks_link    AS INT64)   AS clicks_link,
  CAST(clicks_totales AS INT64)   AS clicks_totales,
  CAST(impressions    AS INT64)   AS impressions
FROM base_spend
;
