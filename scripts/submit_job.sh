#!/bin/bash

# ==============================================================================
# SUBMIT SPARK JOB TO DATAPROC
# Descrição: Submete job para o cluster Dataproc
# ==============================================================================

set -e

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================

PROJECT_ID=${GCP_PROJECT_ID:-""}
REGION=${GCP_REGION:-"us-central1"}
CLUSTER_NAME=${DATAPROC_CLUSTER:-"spark-sentiment-dev"}
BUCKET_NAME=${GCS_BUCKET:-""}

# Validações
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Erro: Defina GCP_PROJECT_ID"
    echo "Exemplo: export GCP_PROJECT_ID='seu-projeto-id'"
    exit 1
fi

if [ -z "$BUCKET_NAME" ]; then
    BUCKET_NAME="${PROJECT_ID}-data-lake"
    echo "ℹ️ Usando bucket padrão: ${BUCKET_NAME}"
fi

# ==============================================================================
# VERIFICAÇÕES PRÉ-SUBMIT
# ==============================================================================

echo "🔍 Verificando cluster..."
if ! gcloud dataproc clusters describe ${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} &>/dev/null; then
    echo "❌ Cluster ${CLUSTER_NAME} não encontrado!"
    echo "Execute: terraform apply"
    exit 1
fi

echo "✅ Cluster ${CLUSTER_NAME} está ativo"

# ==============================================================================
# UPLOAD DO CÓDIGO (se necessário)
# ==============================================================================

read -p "📦 Fazer upload do código atualizado? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 Fazendo upload..."
    ./scripts/package_job.sh ${BUCKET_NAME}
fi

# ==============================================================================
# SUBMIT JOB
# ==============================================================================

JOB_NAME="sentiment-analysis-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Submetendo job: ${JOB_NAME}"

gcloud dataproc jobs submit pyspark \
    gs://${BUCKET_NAME}/jobs/sentiment.py \
    --cluster=${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --id=${JOB_NAME} \
    --properties=spark.executor.memory=2g,spark.driver.memory=2g
    --py-files=gs://${BUCKET_NAME}/jobs/spark_job_package.zip \
    --labels=environment=dev,job-type=streaming

# ==============================================================================
# MONITORAMENTO
# ==============================================================================

echo ""
echo "✅ Job submetido com sucesso!"
echo "📊 ID do Job: ${JOB_NAME}"
echo ""
echo "🔗 Links úteis:"
echo "  Console GCP: https://console.cloud.google.com/dataproc/jobs/${JOB_NAME}?project=${PROJECT_ID}"
echo "  Logs: gcloud dataproc jobs wait ${JOB_NAME} --region=${REGION} --project=${PROJECT_ID}"
echo ""

# Perguntar se quer acompanhar logs
read -p "📜 Acompanhar logs em tempo real? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gcloud dataproc jobs wait ${JOB_NAME} \
        --region=${REGION} \
        --project=${PROJECT_ID}
fi