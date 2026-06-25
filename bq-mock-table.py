"""
BigQuery Mock Data - Domínio Financeiro
Tabelas: contas, transacoes, categorias_transacao

Pré-requisitos:
  pip install google-cloud-bigquery faker

Uso:
  export GOOGLE_CLOUD_PROJECT=seu-projeto
  python bq_mock_financeiro.py --project seu-projeto --dataset seu_dataset
"""

import argparse
import random
from datetime import datetime, timedelta

from faker import Faker
from google.cloud import bigquery

fake = Faker("pt_BR")

# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

SCHEMA_CATEGORIAS = [
    bigquery.SchemaField("categoria_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("nome", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("tipo", "STRING", mode="REQUIRED"),   # CREDITO | DEBITO
    bigquery.SchemaField("icone", "STRING"),
]

SCHEMA_CONTAS = [
    bigquery.SchemaField("conta_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("titular", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("cpf", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("agencia", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("numero_conta", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("tipo_conta", "STRING", mode="REQUIRED"),  # CORRENTE | POUPANCA
    bigquery.SchemaField("saldo", "FLOAT64", mode="REQUIRED"),
    bigquery.SchemaField("limite_credito", "FLOAT64"),
    bigquery.SchemaField("data_abertura", "DATE", mode="REQUIRED"),
    bigquery.SchemaField("ativa", "BOOL", mode="REQUIRED"),
]

SCHEMA_TRANSACOES = [
    bigquery.SchemaField("transacao_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("conta_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("categoria_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("descricao", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("valor", "FLOAT64", mode="REQUIRED"),
    bigquery.SchemaField("tipo", "STRING", mode="REQUIRED"),          # CREDITO | DEBITO
    bigquery.SchemaField("canal", "STRING", mode="REQUIRED"),         # PIX | TED | BOLETO | CARTAO
    bigquery.SchemaField("status", "STRING", mode="REQUIRED"),        # APROVADA | PENDENTE | RECUSADA
    bigquery.SchemaField("data_hora", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("saldo_apos", "FLOAT64"),
]

# ---------------------------------------------------------------------------
# Geradores de dados
# ---------------------------------------------------------------------------

CATEGORIAS_FIXAS = [
    ("CAT001", "Alimentação",      "DEBITO",  "🍽️"),
    ("CAT002", "Transporte",       "DEBITO",  "🚗"),
    ("CAT003", "Saúde",            "DEBITO",  "💊"),
    ("CAT004", "Educação",         "DEBITO",  "📚"),
    ("CAT005", "Lazer",            "DEBITO",  "🎮"),
    ("CAT006", "Moradia",          "DEBITO",  "🏠"),
    ("CAT007", "Salário",          "CREDITO", "💰"),
    ("CAT008", "Transferência Recebida", "CREDITO", "📥"),
    ("CAT009", "Investimento",     "CREDITO", "📈"),
    ("CAT010", "Outros",           "DEBITO",  "📦"),
]

CANAIS = ["PIX", "TED", "BOLETO", "CARTAO"]
STATUS  = ["APROVADA", "APROVADA", "APROVADA", "PENDENTE", "RECUSADA"]  # ponderado


def gerar_categorias():
    return [
        {"categoria_id": c[0], "nome": c[1], "tipo": c[2], "icone": c[3]}
        for c in CATEGORIAS_FIXAS
    ]


def gerar_contas(n: int = 20):
    contas = []
    for i in range(n):
        tipo = random.choice(["CORRENTE", "POUPANCA"])
        saldo = round(random.uniform(-500, 50_000), 2)
        contas.append({
            "conta_id":       f"CTR{str(i+1).zfill(5)}",
            "titular":        fake.name(),
            "cpf":            fake.cpf(),
            "agencia":        str(random.randint(1000, 9999)),
            "numero_conta":   f"{random.randint(10000, 99999)}-{random.randint(0,9)}",
            "tipo_conta":     tipo,
            "saldo":          saldo,
            "limite_credito": round(random.uniform(500, 10_000), 2) if tipo == "CORRENTE" else None,
            "data_abertura":  fake.date_between(start_date="-10y", end_date="today").isoformat(),
            "ativa":          random.choices([True, False], weights=[90, 10])[0],
        })
    return contas


def gerar_transacoes(contas: list, n: int = 200):
    conta_ids   = [c["conta_id"] for c in contas]
    cat_debito  = [c[0] for c in CATEGORIAS_FIXAS if c[2] == "DEBITO"]
    cat_credito = [c[0] for c in CATEGORIAS_FIXAS if c[2] == "CREDITO"]

    descricoes_debito  = ["Supermercado", "Posto de gasolina", "Farmácia", "Mensalidade",
                          "Streaming", "Aluguel", "Restaurante", "Uber", "iFood"]
    descricoes_credito = ["Salário mensal", "Transferência recebida", "Rendimento CDB",
                          "Depósito", "Cashback"]

    transacoes = []
    base_dt = datetime.now() - timedelta(days=90)

    for i in range(n):
        tipo = random.choices(["DEBITO", "CREDITO"], weights=[70, 30])[0]
        valor = round(random.uniform(5, 5_000), 2)
        dt = base_dt + timedelta(
            days=random.randint(0, 90),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59),
        )
        transacoes.append({
            "transacao_id": f"TXN{str(i+1).zfill(7)}",
            "conta_id":     random.choice(conta_ids),
            "categoria_id": random.choice(cat_debito if tipo == "DEBITO" else cat_credito),
            "descricao":    random.choice(descricoes_debito if tipo == "DEBITO" else descricoes_credito),
            "valor":        valor,
            "tipo":         tipo,
            "canal":        random.choice(CANAIS),
            "status":       random.choice(STATUS),
            "data_hora":    dt.strftime("%Y-%m-%dT%H:%M:%S"),
            "saldo_apos":   round(random.uniform(-1_000, 60_000), 2),
        })
    return transacoes


# ---------------------------------------------------------------------------
# BigQuery helpers
# ---------------------------------------------------------------------------

def criar_ou_truncar_tabela(client: bigquery.Client, dataset_ref, nome: str, schema: list):
    table_ref = dataset_ref.table(nome)
    try:
        client.get_table(table_ref)
        print(f"  ⚠️  Tabela '{nome}' já existe — truncando dados anteriores...")
        client.query(f"TRUNCATE TABLE `{table_ref}`").result()
    except Exception:
        table = bigquery.Table(table_ref, schema=schema)
        client.create_table(table)
        print(f"  ✅  Tabela '{nome}' criada.")
    return table_ref


def inserir_linhas(client: bigquery.Client, table_ref, rows: list, nome: str):
    erros = client.insert_rows_json(table_ref, rows)
    if erros:
        print(f"  ❌  Erros ao inserir em '{nome}': {erros}")
    else:
        print(f"  ✅  {len(rows)} linhas inseridas em '{nome}'.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Cria tabelas mock financeiras no BigQuery")
    parser.add_argument("--project", required=True, help="GCP Project ID")
    parser.add_argument("--dataset", required=True, help="BigQuery Dataset ID (deve existir)")
    parser.add_argument("--n_contas",     type=int, default=20,  help="Número de contas (padrão: 20)")
    parser.add_argument("--n_transacoes", type=int, default=200, help="Número de transações (padrão: 200)")
    args = parser.parse_args()

    client      = bigquery.Client(project=args.project)
    dataset_ref = bigquery.DatasetReference(args.project, args.dataset)

    print(f"\n📦 Projeto : {args.project}")
    print(f"📂 Dataset : {args.dataset}\n")

    # 1. Categorias
    print("→ categorias_transacao")
    ref_cat = criar_ou_truncar_tabela(client, dataset_ref, "categorias_transacao", SCHEMA_CATEGORIAS)
    inserir_linhas(client, ref_cat, gerar_categorias(), "categorias_transacao")

    # 2. Contas
    print("\n→ contas")
    ref_con = criar_ou_truncar_tabela(client, dataset_ref, "contas", SCHEMA_CONTAS)
    contas  = gerar_contas(args.n_contas)
    inserir_linhas(client, ref_con, contas, "contas")

    # 3. Transações
    print("\n→ transacoes")
    ref_txn    = criar_ou_truncar_tabela(client, dataset_ref, "transacoes", SCHEMA_TRANSACOES)
    transacoes = gerar_transacoes(contas, args.n_transacoes)
    inserir_linhas(client, ref_txn, transacoes, "transacoes")

    print("\n🎉 Concluído! Tabelas disponíveis no dataset.\n")
    print("Exemplo de query para validar:")
    print(f"  SELECT t.*, c.nome AS categoria, ct.titular")
    print(f"  FROM `{args.project}.{args.dataset}.transacoes` t")
    print(f"  JOIN `{args.project}.{args.dataset}.categorias_transacao` c USING (categoria_id)")
    print(f"  JOIN `{args.project}.{args.dataset}.contas` ct USING (conta_id)")
    print(f"  LIMIT 10;")


if __name__ == "__main__":
    main()
