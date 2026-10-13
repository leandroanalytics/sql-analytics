-- =====================================================================
-- 04_indicadores.sql
-- Módulo 4: consultas para geração de indicadores (KPIs)
-- Usa CTEs (WITH) para organizar o cálculo em etapas legíveis e
-- funções de janela (LAG, SUM OVER) para comparações no tempo.
-- =====================================================================


-- [Q18] Painel executivo — principais indicadores comerciais (1 linha)
-- Receita bruta = antes do desconto | Receita líquida = após desconto.
-- Ticket médio = receita líquida / nº de pedidos.
WITH itens AS (
    SELECT
        SUM(unit_price * quantity)                   AS receita_bruta,
        SUM(unit_price * quantity * (1 - discount))  AS receita_liquida,
        SUM(quantity)                                AS unidades,
        COUNT(*)                                     AS linhas_item
    FROM order_details
),
pedidos AS (
    SELECT
        COUNT(*)                     AS qtd_pedidos,
        COUNT(DISTINCT customer_id)  AS clientes_ativos,
        SUM(freight)                 AS frete_total,
        MIN(order_date)              AS inicio_periodo,
        MAX(order_date)              AS fim_periodo
    FROM orders
)
SELECT
    p.inicio_periodo,
    p.fim_periodo,
    p.qtd_pedidos,
    p.clientes_ativos,
    ROUND(i.receita_bruta, 2)                                   AS receita_bruta,
    ROUND(i.receita_bruta - i.receita_liquida, 2)               AS descontos_concedidos,
    ROUND(100.0 * (i.receita_bruta - i.receita_liquida)
          / i.receita_bruta, 1)                                 AS desconto_pct_receita,
    ROUND(i.receita_liquida, 2)                                 AS receita_liquida,
    ROUND(i.receita_liquida / p.qtd_pedidos, 2)                 AS ticket_medio,
    ROUND(1.0 * i.linhas_item / p.qtd_pedidos, 2)               AS produtos_por_pedido,
    ROUND(p.frete_total, 2)                                     AS frete_total,
    ROUND(100.0 * p.frete_total / i.receita_liquida, 1)         AS frete_pct_receita
FROM itens i
CROSS JOIN pedidos p;


-- [Q19] Nível de serviço logístico (1 linha)
-- No prazo = enviado até a data prometida (shipped_date <= required_date).
WITH enviados AS (
    SELECT
        julianday(shipped_date) - julianday(order_date)     AS dias_ate_envio,
        julianday(shipped_date) - julianday(required_date)  AS dias_vs_prometido
    FROM orders
    WHERE shipped_date IS NOT NULL
)
SELECT
    (SELECT COUNT(*) FROM orders)                                      AS total_pedidos,
    COUNT(*)                                                           AS pedidos_enviados,
    (SELECT COUNT(*) FROM orders WHERE shipped_date IS NULL)           AS pedidos_pendentes,
    ROUND(100.0 * SUM(dias_vs_prometido <= 0) / COUNT(*), 1)           AS no_prazo_pct,
    SUM(dias_vs_prometido > 0)                                         AS pedidos_atrasados,
    ROUND(AVG(CASE WHEN dias_vs_prometido > 0
                   THEN dias_vs_prometido END), 1)                     AS atraso_medio_dias_quando_atrasa,
    ROUND(AVG(dias_ate_envio), 1)                                      AS prazo_medio_envio_dias
FROM enviados;


-- [Q20] Comparativo justo de crescimento: jan–abr/1997 x jan–abr/1998
-- Por que assim: 1996 começa em julho e 1998 termina em 06/05. Comparar
-- anos "cheios" daria uma falsa queda/alta. Aqui comparamos o MESMO
-- período (4 meses completos) em cada ano.
WITH base AS (
    SELECT
        strftime('%Y', o.order_date)                  AS ano,
        o.order_id,
        o.customer_id,
        od.unit_price * od.quantity * (1 - od.discount) AS receita
    FROM orders o
    INNER JOIN order_details od ON od.order_id = o.order_id
    WHERE strftime('%m', o.order_date) BETWEEN '01' AND '04'
      AND strftime('%Y', o.order_date) IN ('1997', '1998')
),
por_ano AS (
    SELECT
        ano,
        COUNT(DISTINCT order_id)     AS pedidos,
        COUNT(DISTINCT customer_id)  AS clientes_ativos,
        SUM(receita)                 AS receita_liquida
    FROM base
    GROUP BY ano
)
SELECT
    ano,
    pedidos,
    clientes_ativos,
    ROUND(receita_liquida, 2)                                          AS receita_liquida,
    ROUND(receita_liquida / pedidos, 2)                                AS ticket_medio,
    -- Variação % sobre o ano anterior (preenchida só na linha de 1998)
    ROUND(100.0 * (1.0 * pedidos / LAG(pedidos) OVER (ORDER BY ano) - 1), 1)               AS var_pedidos_pct,
    ROUND(100.0 * (1.0 * clientes_ativos / LAG(clientes_ativos) OVER (ORDER BY ano) - 1), 1) AS var_clientes_pct,
    ROUND(100.0 * (receita_liquida / LAG(receita_liquida) OVER (ORDER BY ano) - 1), 1)     AS var_receita_pct,
    ROUND(100.0 * ((receita_liquida / pedidos)
                   / LAG(receita_liquida / pedidos) OVER (ORDER BY ano) - 1), 1)           AS var_ticket_pct
FROM por_ano
ORDER BY ano;


-- [Q21] Variação mês contra mês anterior (MoM) com LAG
-- Exclui maio/1998 (mês incompleto: só 6 dias na base).
WITH mensal AS (
    SELECT
        strftime('%Y-%m', o.order_date)                     AS ano_mes,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS receita
    FROM orders o
    INNER JOIN order_details od ON od.order_id = o.order_id
    WHERE o.order_date < '1998-05-01'
    GROUP BY ano_mes
)
SELECT
    ano_mes,
    ROUND(receita, 2)                                         AS receita_liquida,
    ROUND(LAG(receita) OVER (ORDER BY ano_mes), 2)            AS receita_mes_anterior,
    ROUND(100.0 * (receita / LAG(receita) OVER (ORDER BY ano_mes) - 1), 1) AS variacao_mom_pct
FROM mensal
ORDER BY ano_mes;


-- [Q22] Curva ABC de produtos (classificação de Pareto)
-- A = produtos que somam os primeiros 80% da receita,
-- B = de 80% a 95%, C = restante.
-- Por que importa: define prioridade de estoque e negociação.
WITH receita_produto AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS receita
    FROM order_details od
    INNER JOIN products p ON p.product_id = od.product_id
    GROUP BY p.product_id, p.product_name
),
acumulado AS (
    SELECT
        product_id,
        product_name,
        receita,
        100.0 * receita / SUM(receita) OVER ()                         AS participacao_pct,
        100.0 * SUM(receita) OVER (ORDER BY receita DESC, product_id
                                   ROWS UNBOUNDED PRECEDING)
              / SUM(receita) OVER ()                                    AS acumulado_pct
    FROM receita_produto
)
SELECT
    ROW_NUMBER() OVER (ORDER BY receita DESC, product_id) AS posicao,
    product_id,
    product_name,
    ROUND(receita, 2)          AS receita_liquida,
    ROUND(participacao_pct, 2) AS participacao_pct,
    ROUND(acumulado_pct, 2)    AS acumulado_pct,
    CASE
        WHEN acumulado_pct - participacao_pct < 80 THEN 'A'
        WHEN acumulado_pct - participacao_pct < 95 THEN 'B'
        ELSE 'C'
    END                        AS classe_abc
FROM acumulado
ORDER BY posicao;
