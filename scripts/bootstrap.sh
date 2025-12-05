#!/bin/bash

# ==============================================================================
# DATAPROC INITIALIZATION SCRIPT
# Descrição: Instala dependências Python no cluster Dataproc
# Executado: Durante a criação do cluster (antes dos jobs)
# ==============================================================================

set -euxo pipefail

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================

PYTHON_VERSION="python3"
PIP_VERSION="pip3"

# Diretório de logs
LOG_DIR="/var/log/dataproc-initialization"
mkdir -p ${LOG_DIR}
LOG_FILE="${LOG_DIR}/bootstrap-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a ${LOG_FILE})
exec 2>&1

echo "========================================"
echo "DATAPROC BOOTSTRAP - START"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "========================================"

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "Comando $1 não encontrado"
        return 1
    fi
    log_info "Comando $1 OK"
    return 0
}

# ==============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# ==============================================================================

log_info "Atualizando sistema operacional..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    curl \
    wget

# ==============================================================================
# 2. UPGRADE DO PIP
# ==============================================================================

log_info "Atualizando pip..."
${PIP_VERSION} install --upgrade pip setuptools wheel

# ==============================================================================
# 3. INSTALAÇÃO DE DEPENDÊNCIAS PYTHON
# ==============================================================================

log_info "Instalando dependências Python..."

# Ajuste: Trocando kafka-python por kafka-python-ng conforme recomendação de segurança
${PIP_VERSION} install --no-cache-dir \
    pyspark==3.3.2 \
    kafka-python-ng==2.2.2 \
    pandas==2.0.3 \
    pyarrow==12.0.1 \
    nltk==3.8.1 \
    textblob==0.17.1 \
    faker==19.3.1 \
    "numpy<2.0.0"

# Verificar instalações
${PYTHON_VERSION} -c "import pyspark; print(f'PySpark: {pyspark.__version__}')"
${PYTHON_VERSION} -c "import pandas; print(f'Pandas: {pandas.__version__}')"
${PYTHON_VERSION} -c "import nltk; print(f'NLTK: {nltk.__version__}')"

# ==============================================================================
# 4. DOWNLOAD DE DADOS NLTK
# ==============================================================================

log_info "Baixando corpora NLTK..."

NLTK_DATA_DIR="/usr/local/share/nltk_data"
mkdir -p ${NLTK_DATA_DIR}

# Download usando Python
${PYTHON_VERSION} << 'PYTHON_EOF'
import nltk
import os

nltk_data_dir = "/usr/local/share/nltk_data"
os.makedirs(nltk_data_dir, exist_ok=True)

# Download de recursos necessários
resources = [
    'vader_lexicon',
    'punkt',
    'averaged_perceptron_tagger',
    'brown',
    'wordnet'
]

for resource in resources:
    try:
        nltk.download(resource, download_dir=nltk_data_dir, quiet=True)
        print(f"✓ Downloaded: {resource}")
    except Exception as e:
        print(f"✗ Failed: {resource} - {e}")

print("NLTK data path:", nltk.data.path)
PYTHON_EOF

# Configurar variável de ambiente permanente
echo "export NLTK_DATA=${NLTK_DATA_DIR}" >> /etc/profile.d/nltk_data.sh
chmod +x /etc/profile.d/nltk_data.sh

# ==============================================================================
# 5. CONFIGURAÇÕES DO SPARK
# ==============================================================================

log_info "Configurando Spark..."

# Adicionar NLTK_DATA ao spark-env.sh
SPARK_ENV_FILE="/etc/spark/conf/spark-env.sh"
if [ -f "$SPARK_ENV_FILE" ]; then
    echo "export NLTK_DATA=${NLTK_DATA_DIR}" >> ${SPARK_ENV_FILE}
fi

# Configurar Python para Spark
echo "spark.pyspark.python ${PYTHON_VERSION}" >> /etc/spark/conf/spark-defaults.conf
echo "spark.pyspark.driver.python ${PYTHON_VERSION}" >> /etc/spark/conf/spark-defaults.conf

# ==============================================================================
# 6. VALIDAÇÃO
# ==============================================================================

log_info "Executando validações..."

# Teste de importação
${PYTHON_VERSION} << 'VALIDATION_EOF'
import sys
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer

try:
    # Testar VADER
    sid = SentimentIntensityAnalyzer()
    score = sid.polarity_scores("This is a great day!")
    
    if score['compound'] > 0:
        print("✓ NLTK VADER funcionando corretamente")
        sys.exit(0)
    else:
        print("✗ VADER retornou score inesperado")
        sys.exit(1)
except Exception as e:
    print(f"✗ Erro na validação: {e}")
    sys.exit(1)
VALIDATION_EOF

if [ $? -eq 0 ]; then
    log_info "Validação concluída com sucesso"
else
    log_error "Falha na validação"
    exit 1
fi

# ==============================================================================
# 7. LIMPEZA
# ==============================================================================

log_info "Limpando arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# ==============================================================================
# FIM
# ==============================================================================

log_info "Bootstrap concluído com sucesso!"
echo "========================================"
echo "DATAPROC BOOTSTRAP - COMPLETE"
echo "Timestamp: $(date)"
echo "Log file: ${LOG_FILE}"
echo "========================================"

exit 0