-- 03_top_categorias_margen.sql
-- Pregunta de negocio: que categorias generan mas ingresos y cual es su margen bruto?
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Tecnicas: join + funcion de ventana (RANK)

SELECT
p.category AS categoria,
COUNT(oi.id) AS unidades_vendidas,
ROUND(SUM(oi.sale_price), 2) AS ingresos,

-- margen_bruto = ingresos - costo, calculado fila por fila y luego sumado
ROUND(SUM(oi.sale_price - p.cost), 2) AS margen_bruto,

-- margen_pct = margen_bruto / ingresos * 100
ROUND(SAFE_DIVIDE(SUM(oi.sale_price - p.cost), SUM(oi.sale_price)) * 100, 1) AS margen_pct,

-- RANK(): asigna un puesto (1, 2, 3...) a cada categoria segun sus ingresos,
-- de mayor a menor. Funcion de ventana (como LAG), pero para ranking.
-- El ORDER BY de aqui adentro solo afecta el calculo del ranking,
-- es independiente del ORDER BY externo que ordena las filas mostradas.
RANK() OVER (ORDER BY SUM(oi.sale_price) DESC) AS ranking_ingresos

FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
JOIN `bigquery-public-data.thelook_ecommerce.products` p
ON oi.product_id = p.id
WHERE oi.status NOT IN ('Cancelled', 'Returned')
GROUP BY categoria
ORDER BY ingresos DESC
LIMIT 20;
