#!/bin/bash

# ==============================================================================
# DEPLOY COMPLETO (Infraestrutura + Código)
# Descrição: Script all-in-one para deploy inicial
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================

PROJECT_ID=${GCP_PROJECT_ID:-""}
REGION=${GCP_REGION:-"us-central1"}

if [ -z "$PROJECT_ID" ]; then
    log_error "Defina GCP_PROJECT_ID"
    exit 1
fi

BUCKET_NAME="${PROJECT_ID}-data-lake"

# ==============================================================================
# BANNER
# ==============================================================================

cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║       SPARK STREAMING GCP - DEPLOY AUTOMATIZADO               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo ""
log_info "Projeto: ${PROJECT_ID}"
log_info "Região: ${REGION}"
log_info "Bucket: ${BUCKET_NAME}"
echo ""

# ==============================================================================
# ETAPA 1: VALIDAÇÕES PRÉ-DEPLOY
# ==============================================================================

log_info "ETAPA 1: Validando ambiente..."

# Verificar autenticação
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    log_error "Não autenticado no GCloud"
    log_info "Execute: gcloud auth login"
    exit 1
fi

# Verificar se projeto existe
if ! gcloud projects describe ${PROJECT_ID} &>/dev/null; then
    log_error "Projeto ${PROJECT_ID} não encontrado"
    exit 1
fi

log_info "✓ Autenticação OK"

# Verificar APIs habilitadas
REQUIRED_APIS=(
    "compute.googleapis.com"
    "dataproc.googleapis.com"
    "storage.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --project=${PROJECT_ID} | grep -q ${api}; then
        log_info "✓ API habilitada: ${api}"
    else
        log_warn "Habilitando API: ${api}"
        gcloud services enable ${api} --project=${PROJECT_ID}
    fi
done

# ==============================================================================
# ETAPA 2: TERRAFORM INIT & PLAN
# ==============================================================================

log_info "ETAPA 2: Inicializando Terraform..."

cd terraform/environments/dev

terraform init

log_info "Executando terraform plan..."
terraform plan -var="project_id=${PROJECT_ID}" -out=tfplan

read -p "Continuar com apply? (yes/NO): " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    log_error "Deploy cancelado"
    exit 0
fi

# ==============================================================================
# ETAPA 3: TERRAFORM APPLY
# ==============================================================================

log_info "ETAPA 3: Criando infraestrutura..."

terraform apply tfplan

# Extrair outputs
BUCKET_NAME=$(terraform output -raw bucket_name)
CLUSTER_NAME=$(terraform output -raw cluster_name)

cd ../../..

log_info "✓ Infraestrutura criada"
log_info "  Bucket: ${BUCKET_NAME}"
log_info "  Cluster: ${CLUSTER_NAME}"

# ==============================================================================
# ETAPA 4: UPLOAD DO BOOTSTRAP
# ==============================================================================

log_info "ETAPA 4: Fazendo upload do bootstrap script..."

./scripts/upload_bootstrap.sh ${BUCKET_NAME}

log_info "✓ Bootstrap script enviado"

# ==============================================================================
# ETAPA 5: EMPACOTAMENTO E UPLOAD DO CÓDIGO
# ==============================================================================

log_info "ETAPA 5: Empacotando e enviando código..."

./scripts/package_job.sh ${BUCKET_NAME}

log_info "✓ Código enviado para GCS"

# ==============================================================================
# ETAPA 6: AGUARDAR CLUSTER
# ==============================================================================

log_info "ETAPA 6: Aguardando cluster ficar pronto..."

MAX_WAIT=600  # 10 minutos
ELAPSED=0
INTERVAL=15

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(gcloud dataproc clusters describe ${CLUSTER_NAME} \
        --region=${REGION} \
        --project=${PROJECT_ID} \
        --format="value(status.state)" 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$STATUS" == "RUNNING" ]; then
        log_info "✓ Cluster ativo!"
        break
    elif [ "$STATUS" == "ERROR" ]; then
        log_error "Cluster em estado de erro"
        exit 1
    fi
    
    echo -n "."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    log_error "Timeout aguardando cluster"
    exit 1
fi

# ==============================================================================
# RESUMO FINAL
# ==============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
log_info "✅ DEPLOY CONCLUÍDO COM SUCESSO!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📊 Recursos criados:"
echo "  • Cluster Dataproc: ${CLUSTER_NAME}"
echo "  • Bucket GCS: gs://${BUCKET_NAME}"
echo "  • VPC: spark-streaming-vpc"
echo ""
echo "🚀 Próximos passos:"
echo ""
echo "1. Submeter job Spark:"
echo "   ./scripts/submit_job.sh"
echo ""
echo "2. Monitorar via Console:"
echo "   https://console.cloud.google.com/dataproc/clusters?project=${PROJECT_ID}"
echo ""
echo "3. Acessar Spark UI:"
echo "   (Via Component Gateway no console)"
echo ""
echo "⚠️  IMPORTANTE:"
echo "  • Cluster configurado para auto-delete após 1h de idle"
echo "  • Execute './scripts/cleanup.sh' para destruir recursos manualmente"
echo "  • Monitore custos em: https://console.cloud.google.com/billing"
echo ""