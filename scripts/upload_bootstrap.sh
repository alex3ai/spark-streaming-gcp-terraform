#!/bin/bash

# ==============================================================================
# UPLOAD BOOTSTRAP SCRIPT TO GCS
# ==============================================================================

set -e

# Verificar argumentos
if [ $# -ne 1 ]; then
    echo "Uso: $0 BUCKET_NAME"
    exit 1
fi

BUCKET_NAME=$1
BOOTSTRAP_FILE="scripts/bootstrap.sh"

# Verificar se arquivo existe
if [ ! -f "$BOOTSTRAP_FILE" ]; then
    echo "❌ Erro: $BOOTSTRAP_FILE não encontrado"
    exit 1
fi

# Upload para GCS
echo "��� Fazendo upload de $BOOTSTRAP_FILE..."
gsutil cp $BOOTSTRAP_FILE gs://${BUCKET_NAME}/scripts/bootstrap.sh

# Tornar público (opcional - apenas para dev)
# gsutil acl ch -u AllUsers:R gs://${BUCKET_NAME}/scripts/bootstrap.sh

echo "✅ Upload concluído: gs://${BUCKET_NAME}/scripts/bootstrap.sh"
