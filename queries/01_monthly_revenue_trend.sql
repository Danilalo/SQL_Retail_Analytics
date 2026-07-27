-- 01_monthly_revenue_trend.sql
-- Pregunta de negocio: como evolucionan los ingresos mes a mes y cual es la tasa de crecimiento?
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Tecnicas: CTE + GROUP BY + funciones de ventana (LAG) para crecimiento mes a mes
--
-- Nota: la version original intentaba usar LAG() OVER (ORDER BY DATE_TRUNC(...))
-- referenciando oi.created_at directamente dentro del mismo SELECT con GROUP BY.
-- BigQuery lo rechaza (error: Window ORDER BY expression references oi.created_at
-- which is neither grouped nor aggregated) porque la columna cruda ya no existe
-- una vez agrupado. Solucion: separar en dos pasos con un CTE, primero agregar,
-- luego aplicar la funcion de ventana sobre el resultado ya agregado.

WITH monthly AS (
  SELECT
  DATE_TRUNC(DATE(oi.created_at), MONTH) AS mes,
  COUNT(DISTINCT oi.order_id) AS ordenes,
  SUM(oi.sale_price) AS ingresos
  FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
  WHERE oi.status NOT IN ('Cancelled', 'Returned')
  GROUP BY mes
  )

SELECT
mes,
ordenes,
ROUND(ingresos, 2) AS ingresos,
ROUND(ingresos / ordenes, 2) AS ticket_promedio,
ROUND(
  SAFE_DIVIDE(
  ingresos - LAG(ingresos) OVER (ORDER BY mes),
  LAG(ingresos) OVER (ORDER BY mes)
  ) * 100, 1
  ) AS crecimiento_pct_mom

FROM monthly
ORDER BY mes;
