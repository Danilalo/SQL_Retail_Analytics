-- 05_retencion_cohortes.sql
-- Pregunta de negocio: que porcentaje de clientes nuevos vuelve a comprar en los meses posteriores a su primera compra?
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Tecnicas: CTEs encadenadas + analisis de cohortes + funcion de ventana (FIRST_VALUE)

WITH primera_compra AS (
  SELECT
  user_id,
  DATE_TRUNC(DATE(MIN(created_at)), MONTH) AS mes_cohorte
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY user_id
  ),
compras_por_mes AS (
  SELECT
  o.user_id,
  DATE_TRUNC(DATE(o.created_at), MONTH) AS mes_compra
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  WHERE o.status NOT IN ('Cancelled', 'Returned')
  GROUP BY o.user_id, mes_compra
  ),
retencion AS (
  -- Por que un CTE aparte: si se intenta aplicar FIRST_VALUE() en este mismo SELECT
-- reescribiendo DATE_DIFF(cpm.mes_compra, ...) dentro del OVER(), BigQuery lo rechaza:
-- Window ORDER BY expression references cpm.mes_compra which is neither grouped nor aggregated.
-- Dentro de una funcion de ventana solo se puede usar (a) una agregacion fresca (SUM, COUNT...)
-- o (b) una columna ya resuelta en un CTE anterior. Una columna cruda reescrita no cuenta.
SELECT
  pc.mes_cohorte,
  DATE_DIFF(cpm.mes_compra, pc.mes_cohorte, MONTH) AS meses_desde_primera_compra,
  COUNT(DISTINCT cpm.user_id) AS clientes_activos
  FROM primera_compra pc
  JOIN compras_por_mes cpm
  ON pc.user_id = cpm.user_id
  GROUP BY pc.mes_cohorte, meses_desde_primera_compra
  )
SELECT
mes_cohorte,
meses_desde_primera_compra,
clientes_activos,

-- pct_retencion = clientes activos en este mes / clientes activos en el mes 0 de la cohorte
ROUND(
  SAFE_DIVIDE(
  clientes_activos,
  FIRST_VALUE(clientes_activos) OVER (
  PARTITION BY mes_cohorte
  ORDER BY meses_desde_primera_compra
  )
  ) * 100, 1
  ) AS pct_retencion

FROM retencion
ORDER BY mes_cohorte, meses_desde_primera_compra
LIMIT 30;
