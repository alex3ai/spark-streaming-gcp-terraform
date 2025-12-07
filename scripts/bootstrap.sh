#!/bin/bash
set -ex

# ==============================================================================
# SRE HARDENED BOOTSTRAP (FIXED: Added PyArrow)
# ==============================================================================

ROLE=$(/usr/share/google/get_metadata_value attributes/dataproc-role)
echo "Iniciando bootstrap no node: $ROLE"

# 1. Definir Python e Pip Exatos
PYTHON="/usr/bin/python3"
PIP="/usr/bin/python3 -m pip"

# 2. Atualizar Pip
$PIP install --upgrade pip setuptools wheel

# 3. Instalar Dependências
# ADICIONADO: pyarrow==12.0.1 (Essencial para Pandas UDF)
echo "Instalando bibliotecas Python..."
$PIP install --no-cache-dir \
    "numpy<2.0.0" \
    pandas==2.0.3 \
    pyarrow==12.0.1 \
    nltk==3.8.1 \
    textblob==0.17.1 \
    kafka-python-ng==2.2.2 \
    faker==19.3.1

# 4. Configurar NLTK Data (Global)
echo "Baixando dados do NLTK..."
NLTK_DIR="/usr/local/share/nltk_data"
mkdir -p $NLTK_DIR
chmod 777 $NLTK_DIR

$PYTHON -m nltk.downloader -d $NLTK_DIR vader_lexicon punkt averaged_perceptron_tagger

# 5. Configurar Variáveis de Ambiente
echo "Configurando variáveis de ambiente..."
echo "export NLTK_DATA=$NLTK_DIR" >> /etc/profile.d/spark_env.sh
echo "export NLTK_DATA=$NLTK_DIR" >> /etc/spark/conf/spark-env.sh
chmod +x /etc/profile.d/spark_env.sh

echo "✅ Bootstrap concluído com sucesso!"