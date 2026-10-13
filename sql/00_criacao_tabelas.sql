-- =====================================================================
-- 00_criacao_tabelas.sql
-- Estrutura do banco Northwind (SQLite) usada em todo o projeto.
-- Modelo relacional: 8 tabelas, com chaves primárias (PK) e
-- estrangeiras (FK) para garantir a integridade dos JOINs.
--
-- Executado automaticamente por scripts/criar_banco.py
-- =====================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS order_details;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS shippers;

-- Categorias de produto (ex.: Bebidas, Laticínios)
CREATE TABLE categories (
    category_id     INTEGER PRIMARY KEY,
    category_name   TEXT    NOT NULL,
    description     TEXT
);

-- Fornecedores dos produtos
CREATE TABLE suppliers (
    supplier_id     INTEGER PRIMARY KEY,
    company_name    TEXT    NOT NULL,
    contact_name    TEXT,
    contact_title   TEXT,
    city            TEXT,
    region          TEXT,
    country         TEXT,
    phone           TEXT
);

-- Transportadoras
CREATE TABLE shippers (
    shipper_id      INTEGER PRIMARY KEY,
    company_name    TEXT    NOT NULL,
    phone           TEXT
);

-- Clientes (empresas compradoras)
CREATE TABLE customers (
    customer_id     TEXT    PRIMARY KEY,
    company_name    TEXT    NOT NULL,
    contact_name    TEXT,
    contact_title   TEXT,
    address         TEXT,
    city            TEXT,
    region          TEXT,
    postal_code     TEXT,
    country         TEXT,
    phone           TEXT
);

-- Funcionários / vendedores (reports_to = gestor direto)
CREATE TABLE employees (
    employee_id       INTEGER PRIMARY KEY,
    last_name         TEXT    NOT NULL,
    first_name        TEXT    NOT NULL,
    title             TEXT,
    title_of_courtesy TEXT,
    birth_date        DATE,
    hire_date         DATE,
    city              TEXT,
    region            TEXT,
    country           TEXT,
    reports_to        INTEGER REFERENCES employees (employee_id)
);

-- Catálogo de produtos
CREATE TABLE products (
    product_id        INTEGER PRIMARY KEY,
    product_name      TEXT    NOT NULL,
    supplier_id       INTEGER REFERENCES suppliers (supplier_id),
    category_id       INTEGER REFERENCES categories (category_id),
    quantity_per_unit TEXT,
    unit_price        NUMERIC,      -- preço de tabela atual
    units_in_stock    INTEGER,
    units_on_order    INTEGER,
    reorder_level     INTEGER,      -- ponto de reposição
    discontinued      INTEGER NOT NULL  -- 1 = descontinuado
);

-- Cabeçalho do pedido
CREATE TABLE orders (
    order_id        INTEGER PRIMARY KEY,
    customer_id     TEXT    REFERENCES customers (customer_id),
    employee_id     INTEGER REFERENCES employees (employee_id),
    order_date      DATE,
    required_date   DATE,          -- data prometida ao cliente
    shipped_date    DATE,          -- NULL = ainda não enviado
    ship_via        INTEGER REFERENCES shippers (shipper_id),
    freight         NUMERIC,       -- valor do frete
    ship_name       TEXT,
    ship_city       TEXT,
    ship_region     TEXT,
    ship_country    TEXT
);

-- Itens do pedido (1 linha por produto em cada pedido)
CREATE TABLE order_details (
    order_id        INTEGER NOT NULL REFERENCES orders (order_id),
    product_id      INTEGER NOT NULL REFERENCES products (product_id),
    unit_price      NUMERIC NOT NULL,  -- preço praticado na venda
    quantity        INTEGER NOT NULL,
    discount        NUMERIC NOT NULL,  -- 0.05 = 5% de desconto
    PRIMARY KEY (order_id, product_id)
);

-- Índices para acelerar os JOINs mais usados
CREATE INDEX idx_orders_customer   ON orders (customer_id);
CREATE INDEX idx_orders_employee   ON orders (employee_id);
CREATE INDEX idx_orders_date       ON orders (order_date);
CREATE INDEX idx_details_product   ON order_details (product_id);
CREATE INDEX idx_products_category ON products (category_id);
