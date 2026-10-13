-- =====================================================================
-- 01_consultas_basicas.sql
-- Módulo 1: extração de dados com SELECT, WHERE e ORDER BY
-- Banco: database/northwind.db (SQLite)
--
-- Cada consulta começa com um marcador [Qxx]; o notebook
-- notebooks/execucao_consultas.ipynb lê esses marcadores, executa
-- tudo e salva o resultado de cada uma em results/Qxx.csv.
-- =====================================================================


-- [Q01] Os 10 produtos ativos mais caros do catálogo
-- Por que importa: identifica os itens de maior valor unitário, que
-- pedem atenção especial em estoque, negociação e precificação.
SELECT
    product_id,
    product_name,
    quantity_per_unit,
    unit_price,
    units_in_stock
FROM products
WHERE discontinued = 0
ORDER BY unit_price DESC
LIMIT 10;


-- [Q02] Produtos ativos com estoque no ponto de reposição ou abaixo
-- Por que importa: risco de ruptura (falta do produto na prateleira).
-- A coluna "cobertura_com_pedidos" mostra se o que já foi encomendado
-- ao fornecedor resolve o problema ou se é preciso comprar mais.
SELECT
    product_id,
    product_name,
    units_in_stock,
    units_on_order,
    reorder_level,
    CASE
        WHEN units_in_stock + units_on_order > reorder_level
            THEN 'Reposição já encomendada'
        ELSE 'Comprar agora'
    END AS cobertura_com_pedidos
FROM products
WHERE discontinued = 0
  AND units_in_stock <= reorder_level
ORDER BY cobertura_com_pedidos ASC, units_in_stock ASC;  -- "Comprar agora" primeiro


-- [Q03] Pedidos entregues depois da data prometida ao cliente
-- Por que importa: atraso afeta satisfação e recompra. Ordenado do
-- maior para o menor atraso para priorizar a investigação.
SELECT
    order_id,
    customer_id,
    order_date,
    required_date,
    shipped_date,
    CAST(julianday(shipped_date) - julianday(required_date) AS INTEGER) AS dias_atraso
FROM orders
WHERE shipped_date IS NOT NULL
  AND shipped_date > required_date
ORDER BY dias_atraso DESC, order_id;


-- [Q04] Pedidos ainda não enviados (sem data de envio)
-- Por que importa: carteira pendente. "dias_em_aberto" é contado até a
-- última data registrada na base (1998-05-06), não até hoje.
SELECT
    order_id,
    customer_id,
    order_date,
    required_date,
    CAST(julianday('1998-05-06') - julianday(order_date) AS INTEGER) AS dias_em_aberto
FROM orders
WHERE shipped_date IS NULL
ORDER BY order_date;


-- [Q05] Pedidos do 1º trimestre de 1998 com frete acima de 100,
-- enviados para Alemanha, EUA ou Brasil
-- Demonstra combinação de filtros: BETWEEN, IN e operadores lógicos.
SELECT
    order_id,
    customer_id,
    order_date,
    ship_country,
    freight
FROM orders
WHERE order_date BETWEEN '1998-01-01' AND '1998-03-31'
  AND ship_country IN ('Germany', 'USA', 'Brazil')
  AND freight > 100
ORDER BY freight DESC;


-- [Q06] Clientes cujo nome da empresa contém "Restaurant" ou "Café"
-- Demonstra busca textual com LIKE (útil para segmentar o tipo de cliente).
SELECT
    customer_id,
    company_name,
    city,
    country
FROM customers
WHERE company_name LIKE '%Restaurant%'
   OR company_name LIKE '%Café%'
ORDER BY country, company_name;
