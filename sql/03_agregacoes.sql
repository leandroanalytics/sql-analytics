-- =====================================================================
-- 03_agregacoes.sql
-- Módulo 3: agrupamentos e agregações
-- GROUP BY, HAVING e funções SUM, COUNT, AVG, MIN, MAX
--
-- Definição usada em todo o projeto:
--   receita líquida = order_details.unit_price * quantity * (1 - discount)
--   (sem frete; o frete é analisado à parte)
-- =====================================================================


-- [Q12] Receita líquida por categoria de produto
-- Por que importa: mostra onde está o dinheiro do portfólio e ajuda a
-- decidir onde investir em sortimento, estoque e marketing.
SELECT
    cat.category_name                                              AS categoria,
    COUNT(DISTINCT od.order_id)                                    AS qtd_pedidos,
    SUM(od.quantity)                                               AS unidades_vendidas,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)), 2) AS receita_liquida,
    ROUND(AVG(od.discount) * 100, 1)                               AS desconto_medio_pct
FROM order_details od
INNER JOIN products   p   ON p.product_id    = od.product_id
INNER JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_name
ORDER BY receita_liquida DESC;


-- [Q13] Receita líquida por país do cliente — apenas países acima de 50 mil
-- HAVING filtra DEPOIS da agregação (WHERE filtra antes).
SELECT
    c.country                                                      AS pais,
    COUNT(DISTINCT c.customer_id)                                  AS clientes_ativos,
    COUNT(DISTINCT o.order_id)                                     AS qtd_pedidos,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)), 2) AS receita_liquida
FROM orders o
INNER JOIN customers     c  ON c.customer_id = o.customer_id
INNER JOIN order_details od ON od.order_id   = o.order_id
GROUP BY c.country
HAVING SUM(od.unit_price * od.quantity * (1 - od.discount)) > 50000
ORDER BY receita_liquida DESC;


-- [Q14] Desempenho por vendedor
-- Pedidos, receita, ticket médio e desconto médio concedido.
-- O ticket médio é calculado sobre pedidos (receita / nº de pedidos),
-- e não sobre linhas de item — erro comum ao usar AVG direto nos itens.
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name                             AS vendedor,
    e.title                                                        AS cargo,
    COUNT(DISTINCT o.order_id)                                     AS qtd_pedidos,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)), 2) AS receita_liquida,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))
          / COUNT(DISTINCT o.order_id), 2)                         AS ticket_medio,
    ROUND(AVG(od.discount) * 100, 1)                               AS desconto_medio_pct
FROM orders o
INNER JOIN employees     e  ON e.employee_id = o.employee_id
INNER JOIN order_details od ON od.order_id   = o.order_id
GROUP BY e.employee_id, vendedor, e.title
ORDER BY receita_liquida DESC;


-- [Q15] Receita líquida e pedidos por mês
-- Atenção: a base começa em 04/07/1996 e termina em 06/05/1998,
-- então maio/1998 tem só 6 dias e não deve ser comparado como mês cheio.
SELECT
    strftime('%Y-%m', o.order_date)                                AS ano_mes,
    COUNT(DISTINCT o.order_id)                                     AS qtd_pedidos,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)), 2) AS receita_liquida
FROM orders o
INNER JOIN order_details od ON od.order_id = o.order_id
GROUP BY ano_mes
ORDER BY ano_mes;


-- [Q16] Top 10 clientes por receita líquida
-- Inclui primeira e última compra (MIN/MAX) para dar contexto de
-- relacionamento: cliente antigo e ativo x cliente que sumiu.
SELECT
    c.customer_id,
    c.company_name                                                 AS cliente,
    c.country                                                      AS pais,
    COUNT(DISTINCT o.order_id)                                     AS qtd_pedidos,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)), 2) AS receita_liquida,
    MIN(o.order_date)                                              AS primeira_compra,
    MAX(o.order_date)                                              AS ultima_compra
FROM orders o
INNER JOIN customers     c  ON c.customer_id = o.customer_id
INNER JOIN order_details od ON od.order_id   = o.order_id
GROUP BY c.customer_id, c.company_name, c.country
ORDER BY receita_liquida DESC
LIMIT 10;


-- [Q17] Logística por transportadora: frete e prazo
-- Considera só pedidos enviados. "Prazo" = dias entre pedido e envio.
-- O frete fica na tabela orders (1 valor por pedido), então aqui NÃO
-- se junta order_details — juntar duplicaria o frete por item.
SELECT
    s.company_name                                                       AS transportadora,
    COUNT(*)                                                             AS pedidos_enviados,
    ROUND(SUM(o.freight), 2)                                             AS frete_total,
    ROUND(AVG(o.freight), 2)                                             AS frete_medio,
    ROUND(AVG(julianday(o.shipped_date) - julianday(o.order_date)), 1)   AS prazo_medio_dias,
    SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END)    AS pedidos_atrasados,
    ROUND(100.0 * SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                                 AS atraso_pct
FROM orders o
INNER JOIN shippers s ON s.shipper_id = o.ship_via
WHERE o.shipped_date IS NOT NULL
GROUP BY s.company_name
ORDER BY pedidos_enviados DESC;
