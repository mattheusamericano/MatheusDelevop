# ============================================================
# Dataplex Datascan - Exemplo isolado (módulo dataplex-datascan)
# ============================================================
# Convenção de chave: lake_key__scan_key
# bq_table_resource deve apontar para a mesma tabela já registrada
# como Asset no módulo dataplex-asset (boa prática, não validado
# automaticamente pelo Terraform)
# ============================================================

datascan_settings = {

  # ----------------------------------------------------------
  # PROFILE SCAN — Feature Store de treino (spoke-modelagem)
  # Entender distribuição/shape dos dados antes do treino
  # ----------------------------------------------------------
  "modelagem__features-treino-profile" = {
    project_id        = "prj-spoke-modelagem"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "PROFILE"
    bq_table_resource  = "projects/prj-spoke-modelagem/datasets/ds_feature_store_treino/tables/features_consolidadas"
    scan_schedule      = "0 8 * * 1" # toda segunda-feira
    sampling_percent   = 30
    row_filter         = null
    export_results_dataset = "projects/prj-spoke-modelagem/datasets/ds_dataplex_results/tables/profile_features_treino"

    # Colunas excluídas do profile exportado — PII não deve aparecer em resultados agregados
    exclude_fields = ["cpf_hash", "conta_hash"]
    include_fields = []

    labels = {
      camada = "curated"
      uso    = "treino"
    }
  }

  # ----------------------------------------------------------
  # QUALITY SCAN — Feature Store de treino (spoke-modelagem)
  # Validar integridade antes de disparar o pipeline de treino
  # ----------------------------------------------------------
  "modelagem__features-treino-quality" = {
    project_id        = "prj-spoke-modelagem"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "QUALITY"
    bq_table_resource  = "projects/prj-spoke-modelagem/datasets/ds_feature_store_treino/tables/features_consolidadas"
    scan_schedule      = "0 6 * * *" # diário, antes do treino
    incremental_field  = "dt_processamento"
    sampling_percent   = 100
    row_filter         = null
    export_results_dataset = "projects/prj-spoke-modelagem/datasets/ds_dataplex_results/tables/quality_features_treino"

    quality_rules = [
      {
        name      = "id_cliente_nao_nulo"
        column    = "id_cliente_hash"
        dimension = "COMPLETENESS"
        rule_type = "NON_NULL"
        threshold = 1.0
      },
      {
        name      = "score_risco_range"
        column    = "score_risco"
        dimension = "VALIDITY"
        rule_type = "RANGE"
        threshold = 1.0
        range = {
          min        = "0"
          max        = "1000"
          strict_min = false
          strict_max = false
        }
      },
      {
        name           = "segmento_valores_validos"
        column         = "segmento_cliente"
        dimension      = "VALIDITY"
        rule_type      = "SET"
        allowed_values = ["PF", "PJ", "MEI", "GOV"]
        threshold      = 1.0
      },
      {
        name          = "data_referencia_nao_futura"
        column        = "dt_referencia"
        dimension     = "ACCURACY"
        rule_type     = "SQL"
        sql_statement = "SELECT * FROM features_consolidadas WHERE dt_referencia > CURRENT_DATE()"
        threshold     = 1.0
      },
    ]

    labels = {
      camada = "curated"
      uso    = "treino"
    }
  }

  # ----------------------------------------------------------
  # QUALITY SCAN — Feature Store de serving (spoke-inferencia)
  # Garantir que o dado de lookup online é confiável
  # ----------------------------------------------------------
  "inferencia__features-serving-quality" = {
    project_id        = "prj-spoke-inferencia"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "QUALITY"
    bq_table_resource  = "projects/prj-spoke-inferencia/datasets/ds_feature_store_serving/tables/features_online"
    scan_schedule      = "0 2 * * *" # madrugada, antes do pico operacional
    incremental_field  = "dt_atualizacao"
    sampling_percent   = 100
    row_filter         = null
    export_results_dataset = "projects/prj-spoke-inferencia/datasets/ds_dataplex_results/tables/quality_features_serving"

    quality_rules = [
      {
        name      = "feature_chave_nao_nula"
        column    = "id_cliente_hash"
        dimension = "COMPLETENESS"
        rule_type = "NON_NULL"
        threshold = 1.0
      },
      {
        name          = "atualizacao_recente"
        column        = null
        dimension     = "ACCURACY"
        rule_type     = "SQL"
        # Alerta se alguma feature não foi atualizada nas últimas 25h — sinal de drift no pipeline
        sql_statement = "SELECT * FROM features_online WHERE dt_atualizacao < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)"
        threshold     = 1.0
      },
    ]

    labels = {
      camada = "serving"
      uso    = "inferencia"
    }
  }

  # ----------------------------------------------------------
  # PROFILE SCAN — Logs operacionais (spoke-inferencia)
  # Distribuição das predições, suporte ao Model Monitoring
  # ----------------------------------------------------------
  "inferencia__logs-predicao-profile" = {
    project_id        = "prj-spoke-inferencia"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "PROFILE"
    bq_table_resource  = "projects/prj-spoke-inferencia/datasets/ds_logs_operacionais/tables/predicoes"
    scan_schedule      = "0 6 * * 1" # semanal
    sampling_percent   = 10 # logs são volumosos — amostragem reduzida
    row_filter         = null
    export_results_dataset = "projects/prj-spoke-inferencia/datasets/ds_dataplex_results/tables/profile_logs_predicao"

    include_fields = []
    exclude_fields = []

    labels = {
      camada = "raw"
      uso    = "observabilidade"
    }
  }

  # ----------------------------------------------------------
  # QUALITY SCAN — Camada Curated corporativa (hub-features)
  # Porta de qualidade antes da publicação no Analytics Hub
  # ----------------------------------------------------------
  "hub-features__curated-quality" = {
    project_id        = "prj-sipml-gateway-prd"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "QUALITY"
    bq_table_resource  = "projects/prj-sipml-gateway-prd/datasets/ds_curated_corporativo/tables/features_corporativas"
    scan_schedule      = "0 4 * * *"
    incremental_field  = "dt_carga"
    sampling_percent   = 100
    row_filter         = null
    export_results_dataset = "projects/prj-sipml-gateway-prd/datasets/ds_dataplex_results/tables/quality_curated"

    quality_rules = [
      {
        name      = "chave_nao_nula"
        column    = "id_entidade_hash"
        dimension = "COMPLETENESS"
        rule_type = "NON_NULL"
        threshold = 1.0
      },
      {
        name      = "chave_unica"
        column    = "id_entidade_hash"
        dimension = "UNIQUENESS"
        rule_type = "UNIQUENESS"
        threshold = 1.0
      },
      {
        name          = "sem_dados_futuros"
        column        = null
        dimension     = "ACCURACY"
        rule_type     = "SQL"
        sql_statement = "SELECT * FROM features_corporativas WHERE dt_referencia > CURRENT_DATE()"
        threshold     = 1.0
      },
    ]

    labels = {
      camada = "curated"
      uso    = "publicacao-analytics-hub"
    }
  }

  # ----------------------------------------------------------
  # PROFILE SCAN — Camada Curated corporativa (hub-features)
  # Entender shape dos dados antes de publicar
  # ----------------------------------------------------------
  "hub-features__curated-profile" = {
    project_id        = "prj-sipml-gateway-prd"
    region             = "southamerica-east1"
    sigla              = "sipml"
    scan_type          = "PROFILE"
    bq_table_resource  = "projects/prj-sipml-gateway-prd/datasets/ds_curated_corporativo/tables/features_corporativas"
    scan_schedule      = "0 8 * * 1"
    sampling_percent   = 20
    row_filter         = null
    export_results_dataset = "projects/prj-sipml-gateway-prd/datasets/ds_dataplex_results/tables/profile_curated"

    exclude_fields = ["cpf_hash", "cnpj_hash"]
    include_fields = []

    labels = {
      camada = "curated"
      uso    = "publicacao-analytics-hub"
    }
  }
}
