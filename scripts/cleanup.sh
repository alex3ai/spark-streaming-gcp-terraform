#!/bin/bash

# ==============================================================================
# CLEANUP RESOURCES
# Descrição: Remove recursos GCP para evitar custos
# ==============================================================================

set -e

PROJECT_ID=${GCP_PROJECT_ID} # Apenas leia o que foi exportado
REGION=${GCP_REGION:-"us-central1"}

if [ -z "$PROJECT_ID" ];
then
    echo "❌ Erro: A variável GCP_PROJECT_ID deve ser definida!"
    exit 1
fi

echo "⚠️  ATENÇÃO: Este script irá DESTRUIR recursos!"
echo "Projeto: ${PROJECT_ID}" 
echo "Região: ${REGION}"
echo ""
read -p "Continuar? (yes/NO): " -r
echo

if [[ ! $REPLY =~ ^yes$ ]];
then
    echo "❌ Cancelado pelo usuário" 
    exit 0
fi

# ==============================================================================
# PARAR JOBS ATIVOS
# ==============================================================================

echo "🛑 Parando jobs ativos..."

ACTIVE_JOBS=$(gcloud dataproc jobs list \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --filter="status.state=ACTIVE" \
    --format="value(reference.jobId)")

if [ -n "$ACTIVE_JOBS" ];
then
    echo "Jobs ativos encontrados:" 
    echo "$ACTIVE_JOBS"
    
    for job_id in $ACTIVE_JOBS;
    do
        echo "  - Cancelando job: $job_id" 
        gcloud dataproc jobs kill $job_id \
            --region=${REGION} \
            --project=${PROJECT_ID} 
    done
else
    echo "✅ Nenhum job ativo encontrado"
fi

# ==============================================================================
# DESTRUIR INFRAESTRUTURA VIA TERRAFORM
# ==============================================================================

echo ""
echo "🔥 Destruindo infraestrutura Terraform..."
cd terraform/environments/dev

terraform destroy \
    -var="project_id=${PROJECT_ID}" \
    -auto-approve

cd ../../..

# ==============================================================================
# LIMPEZA ADICIONAL (Opcional)
# ==============================================================================

read -p "🗑️  Limpar dados do bucket? (y/N): " -n 1 -r 
echo

if [[ $REPLY =~ ^[Yy]$ ]];
then
    BUCKET_NAME="${PROJECT_ID}-data-lake"
    
    echo "Removendo dados de gs://${BUCKET_NAME}..."
    gsutil -m rm -r gs://${BUCKET_NAME}/data/** 
    gsutil -m rm -r gs://${BUCKET_NAME}/checkpoints/** 
    gsutil -m rm -r gs://${BUCKET_NAME}/logs/**  
    
    echo "✅ Dados removidos (mantendo estrutura de pastas)"
fi

# ==============================================================================
# RESUMO
# ==============================================================================

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ LIMPEZA CONCLUÍDA"
echo "════════════════════════════════════════════════════"
echo ""
echo "Ações realizadas:"
echo "  ✓ Jobs Spark cancelados"
echo "  ✓ Cluster Dataproc destruído"
echo "  ✓ VPC e recursos de rede removidos"
echo ""
echo "⚠️  Lembre-se:"
echo "  - Verifique custos no console GCP"
echo "  - Bucket GCS ainda existe (para preservar dados)"
echo "  - Para deletar tudo: gsutil rm -r gs://${BUCKET_NAME}"
echo ""