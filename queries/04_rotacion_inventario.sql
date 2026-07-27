-- 04_rotacion_inventario.sql
-- Pregunta de negocio: que tan rapido rota el inventario por categoria y donde hay riesgo de quiebre de stock?
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Tecnicas: COUNTIF + DATE_DIFF

SELECT
ii.product_category AS categoria,
COUNT(ii.id) AS items_recibidos,
COUNTIF(ii.sold_at IS NOT NULL) AS items_vendidos,
ROUND(COUNTIF(ii.sold_at IS NOT NULL) / COUNT(ii.id) * 100, 1) AS pct_vendido,
ROUND(AVG(DATE_DIFF(DATE(ii.sold_at), DATE(ii.created_at), DAY)), 1) AS dias_promedio_venta
FROM `bigquery-public-data.thelook_ecommerce.inventory_items` ii
GROUP BY categoria
ORDER BY pct_vendido DESC;
