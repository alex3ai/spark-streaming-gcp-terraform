#!/bin/bash

# ==============================================================================
# PACKAGE JOB FOR GCP SUBMISSION
# Descrição: Empacota o código Python e faz upload para GCS
# ==============================================================================

set -e

# Verificar argumentos
if [ $# -ne 1 ]; then
    echo "Uso: $0 BUCKET_NAME"
    exit 1
fi

BUCKET_NAME=$1
OUTPUT_FILE="spark_job_package.zip"

echo "📦 Empacotando job Spark..."

# Remover pacote antigo para garantir que não haja lixo
rm -f ${OUTPUT_FILE}

# ------------------------------------------------------------------------------
# CRIAÇÃO DO ZIP
# O segredo aqui é zipar a pasta 'app/' recursivamente.
# Isso cria um zip que contém a pasta 'app' na raiz.
# Quando o Spark descompacta, ele vê a pasta 'app', permitindo:
# "from app.config import settings"
# ------------------------------------------------------------------------------
zip -r ${OUTPUT_FILE} app/ \
    -x "*.pyc" \
    -x "*__pycache__/*" \
    -x "app/docs/*" \
    -x "app/scripts/*" \
    -x "*.DS_Store"

echo "✅ Pacote criado: ${OUTPUT_FILE}"

# Upload para GCS
echo "📤 Fazendo upload do pacote para GCS..."
gsutil cp ${OUTPUT_FILE} gs://${BUCKET_NAME}/jobs/

# Upload do arquivo principal do job (sentiment.py) separadamente
# O arquivo principal fica fora do zip para ser o ponto de entrada
echo "📤 Fazendo upload do job principal..."
gsutil cp app/jobs/sentiment.py gs://${BUCKET_NAME}/jobs/

echo "✅ Upload concluído!"
echo "📦 Pacote: gs://${BUCKET_NAME}/jobs/${OUTPUT_FILE}"
echo "📄 Main Job: gs://${BUCKET_NAME}/jobs/sentiment.py"