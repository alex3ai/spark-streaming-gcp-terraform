#!/bin/bash

# ==============================================================================
# PACKAGE JOB FOR GCP SUBMISSION
# Descri√ß√£o: Empacota o c√≥digo Python e faz upload para GCS
# ==============================================================================

set -e

# Verificar argumentos
if [ $# -ne 1 ]; then
    echo "Uso: $0 BUCKET_NAME"
    exit 1
fi

BUCKET_NAME=$1
PACKAGE_DIR="app"
OUTPUT_FILE="spark_job_package.zip"

echo "Ì≥¶ Empacotando job Spark..."

# Remover pacote antigo
rm -f ${OUTPUT_FILE}

# Zipar a pasta 'app' mantendo a estrutura para imports funcionarem
zip -r ${OUTPUT_FILE} ${PACKAGE_DIR} \
    -x "*.pyc" \
    -x "*__pycache__/*" \
    -x "*scripts/*" \
    -x "*.DS_Store"

echo "‚úÖ Pacote criado: ${OUTPUT_FILE}"

# Upload para GCS
echo "Ì≥§ Fazendo upload do pacote para GCS..."
gsutil cp ${OUTPUT_FILE} gs://${BUCKET_NAME}/jobs/

# Upload do arquivo principal do job para a raiz de jobs/
echo "Ì≥§ Fazendo upload do job principal..."
gsutil cp ${PACKAGE_DIR}/jobs/sentiment.py gs://${BUCKET_NAME}/jobs/

echo "‚úÖ Upload conclu√≠do!"
echo "Ì≥Å Pacote: gs://${BUCKET_NAME}/jobs/${OUTPUT_FILE}"
echo "Ì≥Ñ Main Job: gs://${BUCKET_NAME}/jobs/sentiment.py"
