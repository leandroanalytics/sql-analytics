-- =====================================================================
-- 05_perguntas_negocio.sql
-- Módulo 5: perguntas de negócio com visão de gestor
-- Cada consulta responde a uma pergunta que um gestor faria,
-- com o "porquê" da pergunta e o limite do que a base consegue dizer.
-- =====================================================================


-- [Q23] Pergunta: "Quanto a empresa depende dos maiores clientes?"
-- Por que importa: alta concentração = risco. Perder 1 cliente grande
-- pode derrubar a receita; ajuda a dimensionar esforço de retenção.
WITH receita_cliente AS (
    SELECT
        o.customer_id,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS receita
    FROM orders o
    INNER JOIN order_details od ON od.order_id = o.order_id
    GROUP BY o.customer_id
),
ranqueado AS (
    SELECT
        customer_id,
        receita,
        ROW_NUMBER() OVER (ORDER BY receita DESC, customer_id) AS posicao,
        COUNT(*)     OVER ()                                   AS total_clientes,
        SUM(receita) OVER ()                                   AS receita_total
    FROM receita_cliente
)
SELECT
    MAX(total_clientes)                                                     AS clientes_com_compra,
    ROUND(100.0 * SUM(CASE WHEN posicao <= 1  THEN receita END) / MAX(receita_total), 1) AS top1_pct_receita,
    ROUND(100.0 * SUM(CASE WHEN posicao <= 5  THEN receita END) / MAX(receita_total), 1) AS top5_pct_receita,
    ROUND(100.0 * SUM(CASE WHEN posicao <= 10 THEN receita END) / MAX(receita_total), 1) AS top10_pct_receita,
    -- 20% dos clientes que mais compram (regra de Pareto 80/20)
    ROUND(100.0 * SUM(CASE WHEN posicao <= ROUND(total_clientes * 0.2) THEN receita END)
          / MAX(receita_total), 1)                                          AS top20pct_clientes_pct_receita
FROM ranqueado;


-- [Q24] Pergunta: "Quais clientes importantes pararam de comprar?"
-- Critério: sem pedido nos últimos 90 dias da base (data de referência
-- 1998-05-06, última data registrada). Ordenado pela receita histórica
-- para a equipe comercial ligar primeiro para quem mais pesa.
-- Limite: 90 dias é um corte de negócio, não uma regra da base; e a
-- base não diz POR QUE o cliente parou (preço, atendimento, concorrente).
WITH resumo AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.country,
        COUNT(DISTINCT o.order_id)                            AS qtd_pedidos,
        SUM(od.unit_price * od.quantity * (1 - od.discount))  AS receita,
        MAX(o.order_date)                                     AS ultima_compra
    FROM customers c
    INNER JOIN orders        o  ON o.customer_id = c.customer_id
    INNER JOIN order_details od ON od.order_id   = o.order_id
    GROUP BY c.customer_id, c.company_name, c.country
)
SELECT
    customer_id,
    company_name                                                  AS cliente,
    country                                                       AS pais,
    qtd_pedidos,
    ROUND(receita, 2)                                             AS receita_historica,
    ultima_compra,
    CAST(julianday('1998-05-06') - julianday(ultima_compra) AS INTEGER) AS dias_sem_comprar
FROM resumo
WHERE julianday('1998-05-06') - julianday(ultima_compra) > 90
ORDER BY receita DESC;


-- [Q25] Pergunta: "Dar desconto está aumentando o tamanho do pedido?"
-- Compara pedidos SEM nenhum desconto x pedidos COM algum desconto.
-- Limite: é uma comparação, não prova causa. Pedidos grandes podem
-- RECEBER desconto justamente por serem grandes (efeito inverso).
-- Para provar causa seria preciso um teste controlado (A/B).
WITH por_pedido AS (
    SELECT
        order_id,
        MAX(discount) > 0                               AS teve_desconto,
        SUM(quantity)                                   AS unidades,
        SUM(unit_price * quantity)                      AS receita_bruta,
        SUM(unit_price * quantity * (1 - discount))     AS receita_liquida
    FROM order_details
    GROUP BY order_id
)
SELECT
    CASE WHEN teve_desconto THEN 'Com desconto' ELSE 'Sem desconto' END AS tipo_pedido,
    COUNT(*)                                                           AS qtd_pedidos,
    ROUND(AVG(unidades), 1)                                            AS unidades_medias_por_pedido,
    ROUND(AVG(receita_liquida), 2)                                     AS ticket_medio_liquido,
    ROUND(SUM(receita_bruta - receita_liquida), 2)                     AS valor_total_descontado
FROM por_pedido
GROUP BY teve_desconto
ORDER BY tipo_pedido;


-- [Q26] Pergunta: "Quais são os 3 produtos campeões de cada categoria?"
-- ROW_NUMBER particionado por categoria: ranking dentro de cada grupo.
-- Por que importa: orienta vitrine, campanhas e negociação com fornecedor.
WITH receita_produto AS (
    SELECT
        cat.category_name,
        p.product_name,
        p.discontinued,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS receita
    FROM order_details od
    INNER JOIN products   p   ON p.product_id    = od.product_id
    INNER JOIN categories cat ON cat.category_id = p.category_id
    GROUP BY cat.category_name, p.product_name, p.discontinued
),
ranking AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY receita DESC) AS posicao
    FROM receita_produto
)
SELECT
    category_name                                    AS categoria,
    posicao,
    product_name                                     AS produto,
    ROUND(receita, 2)                                AS receita_liquida,
    CASE WHEN discontinued = 1 THEN 'Sim' ELSE 'Não' END AS descontinuado
FROM ranking
WHERE posicao <= 3
ORDER BY categoria, posicao;


-- [Q27] Pergunta: "Estamos dependentes de poucos fornecedores?"
-- Receita gerada pelos produtos de cada fornecedor e sua participação.
-- Por que importa: um fornecedor com fatia grande é ponto único de falha
-- (greve, aumento de preço, ruptura) e também um bom alvo de negociação.
WITH receita_fornecedor AS (
    SELECT
        s.supplier_id,
        s.company_name,
        s.country,
        COUNT(DISTINCT p.product_id)                          AS produtos_vendidos,
        SUM(od.unit_price * od.quantity * (1 - od.discount))  AS receita
    FROM order_details od
    INNER JOIN products  p ON p.product_id  = od.product_id
    INNER JOIN suppliers s ON s.supplier_id = p.supplier_id
    GROUP BY s.supplier_id, s.company_name, s.country
)
SELECT
    company_name                                          AS fornecedor,
    country                                               AS pais,
    produtos_vendidos,
    ROUND(receita, 2)                                     AS receita_liquida,
    ROUND(100.0 * receita / SUM(receita) OVER (), 1)      AS participacao_pct
FROM receita_fornecedor
ORDER BY receita DESC
LIMIT 10;


-- [Q28] Pergunta: "Quanto da receita vem de produtos que já foram descontinuados?"
-- Por que importa: essa receita NÃO vai se repetir. Se a fatia for alta
-- numa categoria, o gestor precisa de produto substituto antes que a
-- receita caia. A última linha (Total) mostra o peso na empresa toda.
WITH receita AS (
    SELECT
        cat.category_name,
        p.discontinued,
        od.unit_price * od.quantity * (1 - od.discount) AS valor
    FROM order_details od
    INNER JOIN products   p   ON p.product_id    = od.product_id
    INNER JOIN categories cat ON cat.category_id = p.category_id
)
SELECT * FROM (
SELECT
    category_name                                                        AS categoria,
    ROUND(SUM(valor), 2)                                                 AS receita_liquida,
    ROUND(SUM(CASE WHEN discontinued = 1 THEN valor ELSE 0 END), 2)      AS receita_descontinuados,
    ROUND(100.0 * SUM(CASE WHEN discontinued = 1 THEN valor ELSE 0 END)
          / SUM(valor), 1)                                               AS descontinuados_pct
FROM receita
GROUP BY category_name
UNION ALL
SELECT
    'Total',
    ROUND(SUM(valor), 2),
    ROUND(SUM(CASE WHEN discontinued = 1 THEN valor ELSE 0 END), 2),
    ROUND(100.0 * SUM(CASE WHEN discontinued = 1 THEN valor ELSE 0 END) / SUM(valor), 1)
FROM receita
)
-- Categorias da maior para a menor dependência; "Total" sempre por último
ORDER BY categoria = 'Total', descontinuados_pct DESC;
