-- 02_aov_by_channel.sql
-- Pregunta de negocio: como varia el ticket promedio (AOV) segun el canal de adquisicion del cliente?
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Tecnicas: CTE + joins de 3 tablas + agregacion

WITH ordenes_valor AS (
SELECT
o.order_id,
o.user_id,
u.traffic_source,
SUM(oi.sale_price) AS valor_orden
FROM `bigquery-public-data.thelook_ecommerce.orders` o
JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
ON o.order_id = oi.order_id
JOIN `bigquery-public-data.thelook_ecommerce.users` u
ON o.user_id = u.id
WHERE o.status NOT IN ('Cancelled', 'Returned')
GROUP BY o.order_id, o.user_id, u.traffic_source
)
SELECT
traffic_source AS canal_adquisicion,
COUNT(order_id) AS total_ordenes,
ROUND(AVG(valor_orden), 2) AS ticket_promedio,
ROUND(SUM(valor_orden), 2) AS ingresos_totales
FROM ordenes_valor
GROUP BY canal_adquisicion
ORDER BY ticket_promedio DESC;
