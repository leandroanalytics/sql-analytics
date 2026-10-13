"""
Executa todas as consultas da pasta sql/ e salva cada resultado em results/.

Cada consulta nos arquivos .sql começa com um marcador no formato
    -- [Q01] Título da consulta
e termina no próximo marcador (ou no fim do arquivo).

Uso (na raiz do repositório):
    python scripts/executar_consultas.py
"""
import re
import sqlite3
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
PASTA_SQL = RAIZ / "sql"
PASTA_RESULTADOS = RAIZ / "results"
ARQUIVO_BANCO = RAIZ / "database" / "northwind.db"

MARCADOR = re.compile(r"^-- \[(Q\d{2})\] (.+)$", re.MULTILINE)


def carregar_consultas() -> list[dict]:
    """Lê os arquivos 01_ a 05_ e separa as consultas pelos marcadores [Qxx]."""
    consultas = []
    for arquivo in sorted(PASTA_SQL.glob("0[1-9]_*.sql")):
        texto = arquivo.read_text(encoding="utf-8")
        marcadores = list(MARCADOR.finditer(texto))
        for i, m in enumerate(marcadores):
            fim = marcadores[i + 1].start() if i + 1 < len(marcadores) else len(texto)
            consultas.append({
                "id": m.group(1),
                "titulo": m.group(2).strip(),
                "arquivo": arquivo.name,
                "sql": texto[m.start():fim].strip(),
            })
    return consultas


def executar(con: sqlite3.Connection, consulta: dict) -> pd.DataFrame:
    df = pd.read_sql_query(consulta["sql"], con)
    # Contagens que o pandas lê como float (ex.: 123.0) voltam a ser inteiros
    for col in df.select_dtypes("float").columns:
        if df[col].dropna().apply(float.is_integer).all() and "receita" not in col:
            df[col] = df[col].astype("Int64")
    return df


def main() -> None:
    PASTA_RESULTADOS.mkdir(exist_ok=True)
    con = sqlite3.connect(ARQUIVO_BANCO)
    for c in carregar_consultas():
        df = executar(con, c)
        df.to_csv(PASTA_RESULTADOS / f"{c['id']}.csv", index=False, encoding="utf-8")
        print(f"{c['id']}  {len(df):>3} linhas  {c['arquivo']:<26} {c['titulo']}")
    con.close()


if __name__ == "__main__":
    main()
