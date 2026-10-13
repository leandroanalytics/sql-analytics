"""
Cria o banco SQLite do projeto a partir dos CSVs em data/.

Uso (na raiz do repositório):
    python scripts/criar_banco.py

Resultado: database/northwind.db
"""
import csv
import sqlite3
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PASTA_DADOS = RAIZ / "data"
ARQUIVO_SCHEMA = RAIZ / "sql" / "00_criacao_tabelas.sql"
ARQUIVO_BANCO = RAIZ / "database" / "northwind.db"

# Ordem de carga respeita as chaves estrangeiras (pais antes dos filhos)
TABELAS = [
    "categories", "suppliers", "shippers", "customers",
    "employees", "products", "orders", "order_details",
]


# Colunas numéricas; o resto (ex.: CEP, telefone, ID do cliente) fica texto
COLUNAS_NUMERICAS = {
    "category_id", "supplier_id", "shipper_id", "employee_id", "reports_to",
    "product_id", "unit_price", "units_in_stock", "units_on_order",
    "reorder_level", "discontinued", "order_id", "ship_via", "freight",
    "quantity", "discount",
}


def converter(coluna: str, valor: str):
    """CSV traz tudo como texto: vazio vira NULL e colunas numéricas viram número."""
    if valor == "":
        return None
    if coluna in COLUNAS_NUMERICAS:
        numero = float(valor)
        return int(numero) if numero.is_integer() and coluna != "discount" else numero
    return valor


def main() -> None:
    ARQUIVO_BANCO.parent.mkdir(exist_ok=True)
    if ARQUIVO_BANCO.exists():
        ARQUIVO_BANCO.unlink()

    con = sqlite3.connect(ARQUIVO_BANCO)
    con.executescript(ARQUIVO_SCHEMA.read_text(encoding="utf-8"))
    # Durante a carga as FKs ficam desligadas (employees referencia a si mesma);
    # a integridade é conferida no final com PRAGMA foreign_key_check.
    con.execute("PRAGMA foreign_keys = OFF")

    for tabela in TABELAS:
        with open(PASTA_DADOS / f"{tabela}.csv", encoding="utf-8", newline="") as f:
            leitor = csv.reader(f)
            colunas = next(leitor)
            linhas = [[converter(c, v) for c, v in zip(colunas, linha)] for linha in leitor]
        marcadores = ",".join("?" * len(colunas))
        con.executemany(
            f"INSERT INTO {tabela} ({','.join(colunas)}) VALUES ({marcadores})",
            linhas,
        )
        print(f"{tabela:<14} {len(linhas):>5} linhas")

    con.commit()
    problemas = con.execute("PRAGMA foreign_key_check").fetchall()
    print("Integridade referencial:", "OK" if not problemas else problemas)
    con.close()
    print(f"Banco criado em {ARQUIVO_BANCO.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
