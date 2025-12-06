#!/bin/bash

# ==============================================================================
# SUBMIT SPARK JOB TO DATAPROC
# Descrição: Submete job para o cluster Dataproc com correção de dependências e ambiente
# ==============================================================================

set -e

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================

# Definições com valores padrão seguros e sem espaços invisíveis
PROJECT_ID=${GCP_PROJECT_ID:-"spark-streaming-gcp-terraform"}
REGION=${GCP_REGION:-"us-central1"}
CLUSTER_NAME=${DATAPROC_CLUSTER:-"spark-sentiment-dev"}
BUCKET_NAME=${GCS_BUCKET:-"${PROJECT_ID}-data-lake"}

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
    echo "Execute: cd terraform/environments/dev && terraform apply"
    exit 1
fi

echo "✅ Cluster ${CLUSTER_NAME} está ativo"

# ==============================================================================
# UPLOAD DO CÓDIGO (Opcional)
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

# --- Construção das Propriedades do Spark ---
# 1. Recursos (Memória/CPU)
PROPS_RESOURCES="spark.executor.memory=2g,spark.driver.memory=2g"

# 2. Pacotes (Conector Kafka) - Injetado via properties, não via flag --packages
PROPS_PACKAGES="spark.jars.packages=org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.2"

# 3. Variáveis de Ambiente para o Spark (Resolve o erro 404 de Bucket)
# Passa o nome correto do bucket para o código Python
PROPS_ENV="spark.yarn.appMasterEnv.GCS_BUCKET=${BUCKET_NAME},spark.executorEnv.GCS_BUCKET=${BUCKET_NAME},spark.yarn.appMasterEnv.GCP_PROJECT_ID=${PROJECT_ID},spark.executorEnv.GCP_PROJECT_ID=${PROJECT_ID}"

# --- Comando de Submissão ---
gcloud dataproc jobs submit pyspark \
    gs://${BUCKET_NAME}/jobs/sentiment.py \
    --cluster=${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --id=${JOB_NAME} \
    --properties="${PROPS_RESOURCES},${PROPS_PACKAGES},${PROPS_ENV}" \
    --py-files=gs://${BUCKET_NAME}/jobs/spark_job_package.zip \
    --archives=gs://${BUCKET_NAME}/jobs/spark_job_package.zip \
    --labels=environment=dev,job-type=streaming

# ==============================================================================
# MONITORAMENTO
# ==============================================================================

echo ""
echo "✅ Job submetido com sucesso!"
echo "📊 ID do Job: ${JOB_NAME}"
echo ""
echo "🔗 Links úteis:"
echo "  Console GCP: https://console.cloud.google.com/dataproc/jobs/${JOB_NAME}?project=${PROJECT_ID}&region=${REGION}"
echo "  Logs: gcloud dataproc jobs wait ${JOB_NAME} --region=${REGION} --project=${PROJECT_ID}"
echo ""

# Perguntar se quer acompanhar logs
read -p "📜 Acompanhar logs em tempo real? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📡 Seguindo logs (Ctrl+C para parar)..."
    gcloud dataproc jobs wait ${JOB_NAME} \
        --region=${REGION} \
        --project=${PROJECT_ID}
fi

echo ""
echo "✅ Para ver outputs do driver:"
echo "   gcloud dataproc jobs describe ${JOB_NAME} --region=${REGION} --format='value(driverOutputResourceUri)' | xargs gsutil cat"