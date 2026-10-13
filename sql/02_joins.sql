-- =====================================================================
-- 02_joins.sql
-- Módulo 2: integração de tabelas com JOIN
-- (INNER JOIN, LEFT JOIN e SELF JOIN)
-- =====================================================================


-- [Q07] Visão completa dos 10 pedidos mais recentes
-- INNER JOIN de 4 tabelas: pedido + cliente + vendedor + transportadora.
-- Transforma códigos (customer_id, employee_id, ship_via) em nomes
-- legíveis — é a base de qualquer relatório operacional.
SELECT
    o.order_id,
    o.order_date,
    c.company_name                        AS cliente,
    c.country                             AS pais_cliente,
    e.first_name || ' ' || e.last_name    AS vendedor,
    s.company_name                        AS transportadora,
    o.freight                             AS frete
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
INNER JOIN employees e ON e.employee_id = o.employee_id
INNER JOIN shippers  s ON s.shipper_id  = o.ship_via
ORDER BY o.order_date DESC, o.order_id DESC
LIMIT 10;


-- [Q08] Itens de pedido enriquecidos com produto, categoria e fornecedor
-- JOIN de 4 tabelas para calcular a receita de cada linha.
-- Receita líquida da linha = preço praticado x quantidade x (1 - desconto).
-- Mostra os 15 itens de maior receita.
SELECT
    od.order_id,
    p.product_name                                          AS produto,
    cat.category_name                                       AS categoria,
    sup.company_name                                        AS fornecedor,
    od.unit_price                                           AS preco_praticado,
    od.quantity                                             AS quantidade,
    od.discount                                             AS desconto,
    ROUND(od.unit_price * od.quantity * (1 - od.discount), 2) AS receita_liquida
FROM order_details od
INNER JOIN products   p   ON p.product_id    = od.product_id
INNER JOIN categories cat ON cat.category_id = p.category_id
INNER JOIN suppliers  sup ON sup.supplier_id = p.supplier_id
ORDER BY receita_liquida DESC
LIMIT 15;


-- [Q09] Clientes cadastrados que nunca fizeram pedido
-- LEFT JOIN + filtro IS NULL: mantém todos os clientes e mostra
-- quem não tem correspondência na tabela de pedidos.
-- Por que importa: leads já cadastrados = oportunidade de ativação.
SELECT
    c.customer_id,
    c.company_name,
    c.city,
    c.country
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.company_name;


-- [Q10] Volume de pedidos por transportadora (incluindo as sem uso)
-- LEFT JOIN + COUNT(o.order_id): transportadoras sem pedidos aparecem
-- com zero em vez de sumirem do resultado (o que um INNER JOIN faria).
SELECT
    s.shipper_id,
    s.company_name       AS transportadora,
    COUNT(o.order_id)    AS qtd_pedidos
FROM shippers s
LEFT JOIN orders o ON o.ship_via = s.shipper_id
GROUP BY s.shipper_id, s.company_name
ORDER BY qtd_pedidos DESC, s.shipper_id;


-- [Q11] Hierarquia da equipe: cada funcionário e seu gestor direto
-- SELF JOIN: a tabela employees é ligada a ela mesma via reports_to.
-- LEFT JOIN para manter quem não tem gestor (o topo da hierarquia).
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name                     AS funcionario,
    e.title                                                AS cargo,
    COALESCE(g.first_name || ' ' || g.last_name, '(topo)') AS gestor_direto
FROM employees e
LEFT JOIN employees g ON g.employee_id = e.reports_to
ORDER BY g.employee_id IS NOT NULL, g.employee_id, e.employee_id;
