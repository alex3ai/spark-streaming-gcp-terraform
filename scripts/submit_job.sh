#!/bin/bash
set -e

# ==============================================================================
# SRE WAR MODE: SUBMIT JOB COM CORREÇÃO DE VERSÃO PYTHON
# ==============================================================================

# Configurações
PROJECT_ID=${GCP_PROJECT_ID:-"spark-streaming-gcp-terraform"}
REGION=${GCP_REGION:-"us-central1"}
CLUSTER_NAME=${DATAPROC_CLUSTER:-"spark-sentiment-dev"}
BUCKET_NAME=${GCS_BUCKET:-"${PROJECT_ID}-data-lake"}

# Validar Projeto
if [ -z "$PROJECT_ID" ]; then echo "❌ Defina GCP_PROJECT_ID"; exit 1; fi

# 1. Empacotar (Garante que o código novo suba)
echo "📦 Empacotando e enviando código..."
./scripts/package_job.sh ${BUCKET_NAME}

# 2. Definir nome do Job
JOB_NAME="sre-validation-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Submetendo job de validação: ${JOB_NAME}"
echo "📝 Modo: STREAM_SOURCE=rate (Dados sintéticos)"

# 3. Submit com FORÇAMENTO DE VERSÃO PYTHON
# Adicionamos: spark.pyspark.python e spark.pyspark.driver.python
# Isso garante que Driver e Worker usem o mesmo binário do sistema (/usr/bin/python3)

gcloud dataproc jobs submit pyspark \
    gs://${BUCKET_NAME}/jobs/sentiment.py \
    --cluster=${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --id=${JOB_NAME} \
    --py-files=gs://${BUCKET_NAME}/jobs/spark_job_package.zip \
    --properties="spark.pyspark.python=/usr/bin/python3,spark.pyspark.driver.python=/usr/bin/python3,spark.yarn.appMasterEnv.STREAM_SOURCE=rate,spark.executorEnv.STREAM_SOURCE=rate,spark.yarn.appMasterEnv.GCS_BUCKET=${BUCKET_NAME},spark.executorEnv.GCS_BUCKET=${BUCKET_NAME}" \
    --labels=env=dev,type=validation

# 4. Monitoramento
echo ""
echo "✅ Job submetido com sucesso!"
echo "👇 Acompanhando logs..."
echo ""

gcloud dataproc jobs wait ${JOB_NAME} --region=${REGION} --project=${PROJECT_ID}