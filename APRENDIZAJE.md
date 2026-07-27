# Aprendizaje — Retail SQL Analytics

Notas técnicas del sprint de BigQuery + Looker Studio. Se va llenando a medida que corremos cada query.

## Setup

- Cuenta de Google Cloud (sandbox gratuito, sin tarjeta).
- BigQuery Studio, dataset público `bigquery-public-data.thelook_ecommerce`.

## ¿Qué es BigQuery y por qué no un SQL "clásico" (MySQL/Postgres)?

- Motores clásicos (MySQL, Postgres, SQL Server) son **OLTP**: optimizados para leer/escribir filas individuales rápido (ej. insertar una orden nueva). Guardan los datos **por filas**.
- BigQuery es **OLAP**: optimizado para agregar millones de filas a la vez (sumas, promedios, agrupaciones) para responder preguntas de negocio. Guarda los datos **por columnas**, así que `SUM(columna)` sobre millones de filas solo lee esa columna — mucho más rápido para analítica.
- Es **serverless**: no hay servidor que administrar, ni índices manuales.
- Usa **Standard SQL**: muy parecido al SQL que ya conoces (SELECT, WHERE, GROUP BY, JOIN), más funciones propias (`SAFE_DIVIDE`, `DATE_TRUNC`) y soporte nativo para datos anidados (ARRAY, STRUCT).
- Por qué importa: Falabella y Mercado Libre piden explícitamente BigQuery + Looker en sus vacantes — es el stack real de retail/e-commerce a gran escala.

## ¿Qué es Looker Studio?

- Herramienta gratuita de Google para dashboards — el equivalente de Google a Power BI.
- No tiene motor de cálculo propio fuerte (no hay algo como DAX): se conecta a una fuente ya procesada (BigQuery, Sheets, Analytics) y visualiza esos resultados.
- Flujo del proyecto: BigQuery calcula los KPIs (las 5 queries) → Looker Studio se conecta y los muestra en gráficas/tarjetas.
- Como ya sabes Power BI, los conceptos (fuente de datos, campos calculados, filtros) son casi los mismos — solo cambia la interfaz.

## Estructura del dataset `thelook_ecommerce`

- `users` — un cliente por fila.
- `orders` — una orden por fila (user_id, estado, fecha).
- `order_items` — un producto dentro de una orden por fila (order_id, product_id, sale_price, status, fechas). Es la tabla más granular.
- `products` — catálogo (id, nombre, categoría, marca, costo, precio).
- `inventory_items` — unidades físicas de inventario.
- Relación: `users` → `orders` → `order_items` → `products`.
- Regla de oro antes de escribir una query de agregación: primero explorar la tabla cruda con `SELECT * ... LIMIT 10` para ver columnas y valores reales, y solo después construir el `GROUP BY`/agregaciones encima.

## Glosario de siglas

| Sigla | Nombre completo (inglés) | Significado |
|---|---|---|
| CTE | Common Table Expression | Tabla temporal nombrada, definida con `WITH nombre AS (...)`, que vive solo dentro de esa query. |
| AOV | Average Order Value | Ticket promedio por orden. |
| OLTP | Online Transaction Processing | Bases de datos tradicionales (MySQL, Postgres) optimizadas para transacciones individuales. |
| OLAP | Online Analytical Processing | Motores como BigQuery, optimizados para analizar grandes volúmenes agregados. |
| ETL | Extract, Transform, Load | Proceso de extraer datos de una fuente, transformarlos, y cargarlos en otro destino. |
| pct_mom | percent, Month over Month | Convención de nombre de columna: % de crecimiento respecto al mes anterior. Variantes: `yoy` (Year over Year), `wow` (Week over Week), `qoq` (Quarter over Quarter). |

## Fórmulas de negocio (consolidado — base para el Word final)

Todas comparten el mismo esqueleto: una diferencia o razón entre dos cantidades, dividida entre una base, multiplicada por 100 para expresarla en porcentaje — y siempre envuelta en `SAFE_DIVIDE` para evitar división entre cero.

**Crecimiento %** (mes a mes, año a año, etc.)
```
crecimiento_% = ((valor_actual - valor_anterior) / valor_anterior) * 100
```
SQL: `SAFE_DIVIDE(actual - LAG(actual) OVER (...), LAG(actual) OVER (...)) * 100`
Ejemplo real (marzo 2019 vs. febrero 2019): `(3198.11 - 588.8) / 588.8 * 100 = 443.2%`. `LAG(x) OVER (ORDER BY ...)` es el "valor_anterior".

**Ticket promedio / AOV** (Average Order Value)
```
AOV = ingresos_totales / número_de_órdenes
```
SQL: `SUM(sale_price) / COUNT(DISTINCT order_id)`, o `AVG(valor_orden)` si ya hay una fila por orden.

**Margen bruto** (gross margin)
```
margen_bruto = ingresos - costo
```
SQL: `SUM(sale_price - cost)` — la resta se hace fila por fila (venta por venta) antes de sumar.

**Margen %** (gross margin percentage)
```
margen_% = (margen_bruto / ingresos) * 100
```
SQL: `SAFE_DIVIDE(SUM(sale_price - cost), SUM(sale_price)) * 100`

## Tipos de JOIN (pregunta típica de entrevista)

- **`JOIN` = `INNER JOIN`** (son sinónimos, `INNER` es opcional). Solo trae filas que tienen coincidencia **en ambas tablas**. Si no hay match, la fila desaparece del resultado silenciosamente — sin error, sin aviso.
- **`LEFT JOIN`** (= `LEFT OUTER JOIN`): trae **todas** las filas de la tabla de la izquierda (la primera que pones), tengan o no match en la derecha. Sin match, las columnas de la derecha salen `NULL` en vez de perder la fila.
- **`RIGHT JOIN`**: espejo de LEFT, prioriza la tabla de la derecha.
- **`FULL OUTER JOIN`**: trae todo de ambas tablas, con `NULL` donde no hay match en ninguna.
- **La pregunta de entrevista real es "por qué" elegiste uno u otro** — no es solo sintaxis: INNER = "solo quiero datos completos, aunque pierda registros"; LEFT = "no quiero perder ningún registro de mi tabla principal, aunque le falte info relacionada".
- **Cómo detectar si importa en un caso real**: comparar `COUNT(*)` con INNER vs. LEFT JOIN sobre las mismas tablas. Si el número es igual, no hay filas huérfanas (el dato está limpio); si LEFT da más, hay registros sin match que INNER estaba escondiendo.

## Orden de escritura vs. orden real de ejecución de SQL

SQL no se ejecuta en el orden en que lo escribes. El `SELECT` se escribe primero mentalmente, pero se resuelve de último.

```
Orden en que escribes:     SELECT → FROM → JOIN → WHERE → GROUP BY → ORDER BY
Orden en que SQL procesa:  FROM → JOIN → WHERE → GROUP BY → SELECT → ORDER BY
```

Por eso puedes usar un alias (ej. `u.traffic_source`) en el `SELECT`, aunque `JOIN users u` aparezca más abajo en el texto — para cuando SQL llega a procesar el `SELECT`, las tablas y sus alias ya fueron resueltos varias etapas antes en el orden real de ejecución.

**Regla sobre alias**: se **declaran** una sola vez, en `FROM tabla alias` o `JOIN tabla alias`. Una vez declarado, se puede **usar** en cualquier otra parte de la query (`SELECT`, `WHERE`, `ON`, `GROUP BY`, `ORDER BY`) sin importar el orden visual en el texto.

## Alias de tabla (`FROM tabla oi`)

- Un alias es un apodo corto para la tabla, para no repetir el nombre completo en cada columna (`oi.status` en vez de `` `bigquery-public-data.thelook_ecommerce.order_items`.status ``).
- El nombre del alias no importa (`oi`, `x`, lo que sea) — es solo legibilidad.
- Con una sola tabla es casi cosmético, pero se vuelve **obligatorio en la práctica** cuando hay `JOIN` entre varias tablas que pueden compartir nombres de columna (ej. `id`, `created_at`) — el alias es la única forma de que SQL sepa de cuál tabla hablas. Va a ser clave en las queries 02 y 03.

## Regla completa de GROUP BY

Toda columna en el `SELECT` tiene que cumplir una de estas dos condiciones:

1. **Estar en el `GROUP BY`** — columnas "crudas", sin función de agregación (ej. `traffic_source`).
2. **Estar envuelta en una función de agregación** (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`) — en ese caso queda **exenta** del `GROUP BY`, porque su trabajo es precisamente colapsar muchas filas en un solo número por grupo.

Ejemplo de la query 02:

```sql
SELECT
  traffic_source AS canal_adquisicion,        -- (1) columna cruda → va en el GROUP BY
  COUNT(order_id) AS total_ordenes,           -- (2) agregación → exenta
  ROUND(AVG(valor_orden), 2) AS ticket_promedio,  -- (2) agregación → exenta
  ROUND(SUM(valor_orden), 2) AS ingresos_totales  -- (2) agregación → exenta
FROM ordenes_valor
GROUP BY canal_adquisicion  -- solo aparece la columna cruda
```

**Por qué funciona así**: el `GROUP BY` define las "cajas" en las que se reparten las filas (una caja por canal). Las funciones de agregación son las que colapsan todo lo que cayó dentro de cada caja en un solo valor — pedirles que también estén en el `GROUP BY` sería contradictorio, ya que son precisamente lo que se está resumiendo, no lo que define los grupos.

## GROUP BY con varias columnas: qué significa realmente "agrupar"

- La cantidad de filas de un resultado agrupado depende **exclusivamente** de cuántas columnas (y qué combinaciones de ellas) van en el `GROUP BY` — no de qué función de agregación (`MIN`, `MAX`, `SUM`...) se use adentro. La función de agregación solo decide qué **valor** poner dentro de cada fila/caja ya definida; no cambia cuántas cajas hay.
- `GROUP BY columna_a` (una sola columna) → una fila por cada valor único de `columna_a`.
- `GROUP BY columna_a, columna_b` (dos columnas) → una fila por cada **combinación única** de `columna_a` + `columna_b`. Esto **no** significa que cada valor de `columna_a` aparezca una sola vez — puede repetirse varias veces, cada vez con un `columna_b` distinto.
- Ejemplo real (query 05): `GROUP BY user_id, mes_compra` — el mismo `user_id` puede aparecer en varias filas (una por cada mes distinto en que compró), pero nunca hay dos filas con la **misma combinación exacta** de `user_id` + `mes_compra`. La regla no es "cada user_id una sola vez", es "cada combinación (user_id, mes_compra) una sola vez".

## Patrón: agregar dos veces, en dos niveles distintos (CTE → SELECT externo)

Tanto la query 01 como la 02 usan la misma estructura:

1. **CTE**: agrega los datos crudos a un nivel de detalle intermedio (query 01: por mes; query 02: por orden individual).
2. **SELECT externo**: toma ese resultado ya agregado y lo vuelve a agregar a un nivel más alto (query 01: aplica `LAG` sobre los meses; query 02: promedia/suma las órdenes agrupándolas por canal).

**Por qué se hace en dos pasos y no en uno solo**: en la query 02, si quisiéramos el AOV (ticket promedio, *Average Order Value*) por canal directamente sobre las filas crudas de `order_items` (sin pasar primero por "una fila por orden"), estaríamos promediando precios de **productos individuales**, no de **órdenes completas** — un número sin sentido de negocio. Necesitamos primero colapsar a "una fila = una orden" (CTE), y solo después promediar esas órdenes por canal (SELECT externo). Es la misma razón por la que en la query 01 no podíamos calcular `LAG` directamente sobre `oi.created_at` sin agregar primero por mes.

**Regla general**: cuando la pregunta de negocio tiene dos niveles de granularidad (ej. "en promedio, por orden, agrupado por canal"), casi siempre se necesitan dos pasos de agregación — uno por nivel — no uno solo.

## Conceptos por query

### Query 02 — AOV (Average Order Value / ticket promedio) por canal de adquisición

- **JOIN triple encadenado**: `orders` + `order_items` (por `order_id`) + `users` (por `user_id` = `id`). Cada `JOIN` se conecta con todo lo ya combinado antes, no con la tabla original sola — no son "3 joins simultáneos", son secuenciales.
- **Ningún JOIN en BigQuery está respaldado por una llave foránea real** — el motor no lo verifica, es responsabilidad del analista confirmar que la relación tiene sentido (explorando tablas primero, o comparando `COUNT(*)` con INNER vs. LEFT JOIN).
- **Ruido de `FLOAT64`**: `sale_price` puede salir como `9.9499998092651367` en vez de `9.95` — es la representación binaria aproximada de decimales, no un error. Por eso siempre se envuelve en `ROUND(..., 2)`.
- **`HAVING` vs. `WHERE`**: `WHERE` filtra filas antes de agrupar; `HAVING` filtra grupos después de agrupar (ej. `GROUP BY order_id HAVING COUNT(*) > 1` para encontrar órdenes con más de un producto).

## Lección: verificar paginación antes de sacar conclusiones

Al correr la query 01 salieron 50 filas (2019-01 a 2023-02), y la última mostraba -17% de crecimiento. Hipótesis inicial: "el último mes está incompleto, por eso cae." Pero al chequear `SELECT MAX(created_at)` la fecha real más reciente en la tabla resultó ser 2026-07-29 — muy posterior a 2023-02.

**Causa real**: el panel de resultados de BigQuery Studio pagina de a 50 filas por defecto. La query sí calculó todos los meses (~91, de 2019-01 a 2026-07), pero la UI solo mostraba la primera página. La fila "final" que vimos no era el final real de los datos.

**Regla general**: nunca asumas que la última fila visible en pantalla es la última fila real del resultado. Verifica con `COUNT(*)` sobre el resultado, o revisa los controles de paginación, antes de sacar conclusiones sobre "el dato más reciente" o "el último período".

### Query 01 — Tendencia de ingresos mensual

- **Función de ventana (`LAG`)**: a diferencia de `GROUP BY` (que colapsa filas), una función de ventana calcula algo mirando otras filas sin perder el detalle de la fila actual. `LAG(x) OVER (ORDER BY ...)` trae el valor de `x` en la fila anterior — útil para comparar "este mes vs. el anterior".
- **`SAFE_DIVIDE(a, b)`**: división que devuelve `NULL` en vez de error si `b` es 0.
- **Error real encontrado**: `Window ORDER BY expression references oi.created_at which is neither grouped nor aggregated`. Pasa porque dentro de un `SELECT` con `GROUP BY`, no puedes referenciar la columna cruda (`oi.created_at`) dentro de una función de ventana — una vez agrupado, esa columna ya no existe fila por fila.
- **Solución — CTE (`WITH ... AS (...)`)**: una tabla temporal dentro de la misma query. Patrón: primero agregar en el CTE (GROUP BY normal, sin funciones de ventana), y en un `SELECT` externo aparte aplicar la función de ventana sobre las columnas ya agregadas y limpias (`mes`, `ingresos`), donde no hay ambigüedad. Regla general: **si necesitas una función de ventana sobre un resultado agregado, agrega primero en un CTE y aplica la ventana después.**
- **Regla afinada (confirmada experimentalmente en la query 05):** dentro de una función de ventana, en un `SELECT` con `GROUP BY`, solo se puede usar (a) funciones de agregación frescas calculadas ahí mismo (`SUM`, `COUNT`, `AVG`...) — por eso `RANK() OVER (ORDER BY SUM(...))` sí funciona directo en la query 03 sin CTE extra — o (b) columnas que ya pasaron por un CTE anterior y quedaron resueltas. Lo que **nunca** funciona es reescribir una columna cruda dentro del `OVER(...)`, aunque esa misma expresión ya forme parte del `GROUP BY` por otro lado (BigQuery no la reconoce como "la misma cosa", solo ve una columna sin agregar).

**Ejemplo básico de la regla (por qué hace falta el CTE):**

Tabla `ventas`:

| dia | monto |
|---|---|
| 2024-01-01 | 100 |
| 2024-01-15 | 200 |
| 2024-02-01 | 50 |
| 2024-02-20 | 150 |

Quiero el total por mes, y comparar cada mes contra el primero.

Versión que **falla** (mismo error que en la query 05):
```sql
SELECT
  DATE_TRUNC(dia, MONTH) AS mes,
  SUM(monto) AS total,
  FIRST_VALUE(SUM(monto)) OVER (ORDER BY DATE_TRUNC(dia, MONTH)) AS primer_mes
FROM ventas
GROUP BY mes
```
`SUM(monto)` adentro del `FIRST_VALUE` está bien (agregación fresca). El problema es `ORDER BY DATE_TRUNC(dia, MONTH)`: usa `dia`, la columna cruda, sin resumir — aunque esa expresión es literalmente el `mes` del `GROUP BY`, BigQuery no hace esa conexión y la rechaza.

Versión que **funciona** — se resuelve el `GROUP BY` en un CTE aparte, y el `SELECT` de afuera ya no toca `dia`, solo usa `mes` y `total` (columnas reales y cerradas):
```sql
WITH por_mes AS (
  SELECT DATE_TRUNC(dia, MONTH) AS mes, SUM(monto) AS total
  FROM ventas
  GROUP BY mes
)
SELECT mes, total, FIRST_VALUE(total) OVER (ORDER BY mes) AS primer_mes
FROM por_mes
```

Regla en una frase: **una función de ventana solo puede usar cosas ya "cerradas y con nombre"** (una suma/conteo hecho ahí mismo, o una columna que ya salió de un `GROUP BY` anterior) — **nunca la columna original sin procesar**, aunque se vea "igual" a algo del `GROUP BY`.

### Query 05 — Retención de clientes (cohortes)

- **Análisis de cohortes**: agrupar clientes por su mes de primera compra ("cohorte"), y luego medir qué % de ese grupo sigue comprando en los meses siguientes. Es la técnica estándar para responder "¿retenemos clientes o los perdemos después de la primera compra?".
- **`PARTITION BY`**: reinicia el cálculo de una función de ventana por cada grupo, **sin colapsar filas** (a diferencia de `GROUP BY`, que sí las colapsa). `PARTITION BY mes_cohorte` significa "calcula esto por separado para cada cohorte, sin mezclar una cohorte con otra".
- **`FIRST_VALUE(x) OVER (PARTITION BY ... ORDER BY ...)`**: devuelve, en cada fila, el valor de `x` de la **primera fila** de ese grupo (según el `ORDER BY` interno) — sin perder el resto de las filas. Aquí: `FIRST_VALUE(clientes_activos) OVER (PARTITION BY mes_cohorte ORDER BY meses_desde_primera_compra)` trae, en cada fila, cuántos clientes tenía esa cohorte en el mes 0 (su tamaño inicial), para poder dividir y sacar el % de retención.
- **Por qué necesitó un tercer CTE**: ver la explicación y el ejemplo básico arriba — `meses_desde_primera_compra` y `clientes_activos` tenían que quedar resueltos en un CTE (`retencion`) antes de poder usarlos dentro de `FIRST_VALUE(...) OVER (...)`.

**Resultado real e interpretación honesta:**

| mes_cohorte | meses_desde_primera_compra | clientes_activos | pct_retencion |
|---|---|---|---|
| 2019-01-01 | 0 | 5 | 100.0 |
| 2019-01-01 | 74 | 1 | 20.0 |
| 2019-02-01 | 0 | 14 | 100.0 |
| 2019-02-01 | 68 | 2 | 14.3 |
| 2019-03-01 | 0 | 31 | 100.0 |
| 2019-03-01 | 8 | 2 | 6.5 |

No hay una curva de retención suave y decreciente como se esperaría en un negocio real (ej. 100% → 40% → 25% → 15%...). En vez de eso: cohortes muy pequeñas (5, 14, 31 clientes), casi todos los meses posteriores muestran **1 solo cliente activo**, y aparecen "regresos" dispersos hasta el mes 74 u 83 — algo poco realista en retail real, donde la retención decae y se estabiliza, no reaparece al azar años después.

**Causa más probable**: cohortes tan pequeñas que un solo cliente mueve el % dramáticamente (1 de 5 = 20%, 1 de 31 = 3.2%) — no hay suficiente volumen por cohorte para que un patrón real se note. Esto es consistente con lo ya visto en la query 04 (rotación de inventario uniforme): `thelook_ecommerce` es un dataset sintético, generado con probabilidades más o menos parejas, no con comportamiento real de clientes que vuelven o no vuelven. **Conclusión honesta para el hallazgo**: la metodología (cohortes + % retención) es correcta y es la que se usaría en un caso real, pero con este dataset el resultado no es interpretable como "tendencia de negocio" — es ruido estadístico por tamaño de muestra pequeño, no una señal real de retención.

