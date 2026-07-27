# Retail SQL Analytics — The Look E-commerce

Proyecto de portafolio: análisis de KPIs de negocio (ingresos, ticket promedio, márgenes, inventario y retención) sobre el dataset público de BigQuery `bigquery-public-data.thelook_ecommerce`, que simula un negocio de e-commerce/retail.

## Por qué este proyecto

Práctica dirigida de SQL (CTEs, funciones de ventana, joins multi-tabla, agregaciones) usando Google BigQuery + Looker Studio, el mismo stack que piden la mayoría de vacantes de Data/BI Analyst en retail y finanzas (ej. GCP, BigQuery, Looker).

## Preguntas de negocio

1. **Tendencia de ingresos** — ¿cómo evolucionan los ingresos mes a mes y cuál es la tasa de crecimiento? → `queries/01_monthly_revenue_trend.sql`
2. **Ticket promedio por canal** — ¿varía el AOV según el canal de adquisición del cliente? → `queries/02_aov_by_channel.sql`
3. **Categorías top y margen** — ¿qué categorías generan más ingresos y cuál es su margen bruto? → `queries/03_top_categorias_margen.sql`
4. **Rotación de inventario** — ¿qué tan rápido rota el stock por categoría y dónde hay riesgo de quiebre? → `queries/04_rotacion_inventario.sql`
5. **Retención de clientes** — ¿qué porcentaje de clientes nuevos vuelve a comprar en los meses siguientes? (cohortes) → `queries/05_retencion_cohortes.sql`

## Stack

- **BigQuery** (sandbox gratuito, dataset público) — motor SQL
- **Looker Studio** (gratuito) — dashboard conectado directo a BigQuery
- **SQL estándar de BigQuery** — CTEs, `LAG`/`RANK` (funciones de ventana), `SAFE_DIVIDE`, `DATE_TRUNC`, `DATE_DIFF`, `COUNTIF`

## Cómo correrlo

1. Crear cuenta gratuita en [Google Cloud](https://cloud.google.com/free) (sandbox de BigQuery, sin tarjeta de crédito para este caso de uso).
2. Abrir BigQuery Studio → pegar cada archivo de `queries/` → Run.
3. Guardar resultados como vista o exportar a Google Sheets.
4. Conectar Looker Studio a BigQuery y armar 1 dashboard con las 5 preguntas.
5. Completar la sección de Hallazgos abajo con los resultados reales.

## Hallazgos

**Nota sobre el dataset:** `thelook_ecommerce` es un dataset sintético y de generación continua (los datos llegan hasta fechas recientes, no es un histórico congelado). Los números absolutos cambian si se re-ejecutan las queries más adelante; los patrones y la metodología se mantienen.

**1. Tendencia de ingresos** — crecimiento sostenido de 2019 a la fecha. Los primeros meses del dataset (bajo volumen inicial) no son representativos y se excluyen del análisis de tendencia.

**2. Ticket promedio (AOV) por canal** — el canal de adquisición apenas influye en el AOV: varía solo 3.6% entre el canal más alto (Email, $88.51) y el más bajo (Organic, $85.41). En cambio, el volumen de órdenes varía enormemente: Search concentra 66,016 órdenes (~14x más que Email) y domina los ingresos totales ($5.69M) por encima de los demás canales combinados. Conclusión: el canal que impulsa el negocio es el de mayor volumen, no el de mejor ticket promedio — aunque sin datos de costo de adquisición por canal, no se puede concluir cuál es más rentable.

**3. Categorías top por ingresos y margen** — "vender más" y "ser rentable" no son lo mismo. `Outerwear & Coats` lidera en ingresos ($984,736) con buen margen (55.5%) — la categoría más sólida. `Jeans` es #2 en ingresos ($962,692) pero tiene uno de los márgenes más bajos del top (46.5%). En el otro extremo, `Blazers & Jackets` apenas ocupa el puesto #15 en ingresos pero tiene el mejor margen bruto de todas (62.0%) — candidata a más inversión en marketing, ya que cada venta adicional es desproporcionadamente rentable.

**4. Rotación de inventario** — a diferencia de ingresos y margen (donde sí hay diferencias marcadas entre categorías), la rotación de inventario es prácticamente uniforme: el % de unidades vendidas va de 36.0% (Clothing Sets) a 37.3% (Jumpsuits & Rompers) — apenas 1.3 puntos de diferencia entre las 26 categorías — y el tiempo promedio de venta se mantiene entre 29.5 y 30.4 días en todos los casos. No hay categorías que roten claramente más rápido o más lento. Esta uniformidad es en sí misma un hallazgo: sugiere que el dataset simula ventas con una probabilidad aproximadamente constante por categoría, no una demanda diferenciada realista — refuerza que los números absolutos de este proyecto son ilustrativos, no un caso de negocio real.

**5. Retención de clientes (cohortes)** — la metodología (agrupar por mes de primera compra, medir % activo en meses posteriores) es la estándar de la industria, pero el resultado no muestra una curva de retención real: los cohortes son pequeños (5 a 31 clientes por mes), así que un solo cliente activo mueve el % dramáticamente (ej. 1 de 5 = 20%), y aparecen "regresos" dispersos hasta 70+ meses después — poco realista en retail real, donde la retención decae de forma suave y se estabiliza. Mismo patrón que el hallazgo 4: consistente con un dataset sintético generado con probabilidades parejas, no con comportamiento real de clientes. Conclusión honesta: la técnica está bien aplicada, pero el resultado es ruido estadístico por tamaño de cohorte pequeño, no una señal de negocio.

## Estado del proyecto

Las 5 queries ejecutadas contra BigQuery real y verificadas. Pendiente: dashboard en Looker Studio y push a GitHub.
