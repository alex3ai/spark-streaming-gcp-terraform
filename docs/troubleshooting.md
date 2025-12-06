# 🔧 TROUBLESHOOTING GUIDE

**Projeto**: Spark Streaming GCP (Terraform/Dataproc)  
**Última Atualização**: Dezembro 2024  
**Autor**: SRE Team

---

## 📋 Índice

1. [Problemas de Quota](#1-erro-quota-exceeded-ao-criar-cluster)
2. [Cluster em CREATING Travado](#2-cluster-fica-em-estado-creating-por-muito-tempo)
3. [Falhas de Dependências Python](#3-job-falha-com-modulenotfounderror-nltk)
4. [Erros de Permissão GCS](#4-erro-permission-denied-ao-acessar-gcs)
5. [Custos Inesperados](#5-custos-inesperados)
6. [Checkpoint Inacessível](#6-checkpoint-location-inacessível)
7. [Falhas de Componentes Hive](#7-component-hive-metastorehive-server2-failed)
8. [Logs Úteis](#logs-úteis)
9. [Comandos de Emergência](#comandos-de-emergência)

---

## 1. Erro: "Quota exceeded" ao criar cluster

### Sintoma

```
ERROR: (gcloud.dataproc.clusters.create) RESOURCE_EXHAUSTED: Quota 'CPUS' exceeded
```

### Causa
Projeto GCP atingiu o limite de vCPUs disponíveis na região.

### Solução

**A. Verificar quotas atuais:**
```bash
gcloud compute project-info describe \
  --project=spark-streaming-gcp-terraform \
  --format="table(quotas.metric,quotas.limit,quotas.usage)"
```

**B. Solicitar aumento de quota:**
1. Acesse: https://console.cloud.google.com/iam-admin/quotas
2. Filtrar por "CPUs" na região `us-central1`
3. Selecione a quota e clique em "EDIT QUOTAS"
4. Solicite aumento (geralmente aprovado em minutos para Free Tier)

**C. Alternativa (reduzir cluster temporariamente):**
```hcl
# terraform/environments/dev/terraform.tfvars
master_machine_type = "e2-small"  # 2 vCPUs, 2GB RAM (mínimo viável)
```

⚠️ **Nota**: `e2-small` NÃO é recomendado para produção (apenas testes rápidos).

---

## 2. Cluster fica em estado "CREATING" por muito tempo

### Sintoma
Cluster não fica pronto após 10-15 minutos, fica travado em `CREATING`.

### Diagnóstico

**Passo 1: Verificar status detalhado**
```bash
gcloud dataproc clusters describe spark-sentiment-dev \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform \
  --format="value(status.state,status.detail)"
```

**Passo 2: Ver logs de erro do bootstrap**
```bash
# Listar diretório de metadados
gsutil ls gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/

# Encontrar o UUID do cluster (última pasta criada)
CLUSTER_UUID=$(gsutil ls gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/ | tail -1)

# Ver logs do bootstrap script
gsutil cat ${CLUSTER_UUID}spark-sentiment-dev-m/dataproc-initialization-script-0_output
```

**Passo 3: Ver logs do agente Dataproc**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --project=spark-streaming-gcp-terraform \
  --command="sudo journalctl -u google-dataproc-agent -n 100"
```

### Soluções Comuns

**A. Timeout de inicialização insuficiente:**
```hcl
# terraform/modules/dataproc/main.tf
initialization_action {
  script      = "gs://${var.staging_bucket_name}/scripts/bootstrap.sh"
  timeout_sec = 900  # Aumentar para 15 minutos
}
```

**B. Falha no download de dependências (rede):**
```bash
# Verificar se o cluster tem acesso à internet
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --command="curl -I https://pypi.org"
```

Se falhar, habilitar IP externo temporariamente:
```hcl
# terraform/modules/dataproc/main.tf
gce_cluster_config {
  internal_ip_only = false  # Permitir acesso à internet
}
```

---

## 3. Job falha com "ModuleNotFoundError: nltk"

### Sintoma
```
ModuleNotFoundError: No module named 'nltk'
Traceback (most recent call last):
  File "/app/jobs/sentiment.py", line 3, in <module>
    import nltk
```

### Causa
Bootstrap script não executou corretamente ou falhou silenciosamente.

### Solução

**Passo 1: Verificar logs do bootstrap**
```bash
CLUSTER_UUID=$(gsutil ls gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/ | tail -1)
gsutil cat ${CLUSTER_UUID}spark-sentiment-dev-m/dataproc-initialization-script-0_output | grep -A 10 "ERROR\|FAILED"
```

**Passo 2: SSH no master e validar instalação**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --project=spark-streaming-gcp-terraform

# Dentro da VM:
python3 -c "import nltk; print(nltk.__version__)"
python3 -c "import nltk; print(nltk.data.path)"
ls -la /usr/local/share/nltk_data/
```

**Passo 3: Reinstalar manualmente (workaround temporário)**
```bash
# Ainda dentro da VM:
sudo pip3 install nltk==3.8.1
python3 -m nltk.downloader -d /usr/local/share/nltk_data vader_lexicon
```

**Correção Permanente:**
```bash
# Verificar se bootstrap.sh tem permissão de execução
ls -l scripts/bootstrap.sh  # Deve ter 'x' (executável)

# Se não tiver:
chmod +x scripts/bootstrap.sh
git add scripts/bootstrap.sh
git commit -m "fix(scripts): add execute permission to bootstrap.sh"

# Re-upload para GCS
gsutil cp scripts/bootstrap.sh gs://spark-streaming-gcp-terraform-data-lake/scripts/
```

---

## 4. Erro: "Permission denied" ao acessar GCS

### Sintoma
```
com.google.cloud.hadoop.fs.gcs.GoogleCloudStorageFileSystem: Access denied
java.io.IOException: Error accessing gs://spark-streaming-gcp-terraform-data-lake/checkpoints/
```

### Causa
Service Account do Dataproc não tem permissões IAM corretas no bucket.

### Solução

**Passo 1: Identificar Service Account do cluster**
```bash
SA_EMAIL=$(gcloud dataproc clusters describe spark-sentiment-dev \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform \
  --format="value(config.gceClusterConfig.serviceAccount)")

echo "Service Account: $SA_EMAIL"
```

**Passo 2: Verificar permissões atuais**
```bash
gcloud projects get-iam-policy spark-streaming-gcp-terraform \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}" \
  --format="table(bindings.role)"
```

**Passo 3: Adicionar permissão faltante**
```bash
# Permissão completa no bucket (objectAdmin)
gcloud projects add-iam-policy-binding spark-streaming-gcp-terraform \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Permissão de leitura de metadados (para listar buckets)
gcloud projects add-iam-policy-binding spark-streaming-gcp-terraform \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.legacyBucketReader"
```

**Passo 4: Validar acesso**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --command="gsutil ls gs://spark-streaming-gcp-terraform-data-lake/"
```

---

## 5. Custos Inesperados

### Sintoma
Cobrança maior que o esperado (ex: $50+ em uma semana de testes).

### Diagnóstico

**A. Verificar recursos ativos**
```bash
# Listar VMs rodando
gcloud compute instances list \
  --project=spark-streaming-gcp-terraform \
  --format="table(name,zone,machineType,status)"

# Listar clusters Dataproc
gcloud dataproc clusters list \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform
```

**B. Verificar uso de storage**
```bash
# Tamanho total do bucket
gsutil du -sh gs://spark-streaming-gcp-terraform-data-lake/

# Top 10 maiores arquivos
gsutil du -h gs://spark-streaming-gcp-terraform-data-lake/** | sort -h | tail -10
```

**C. Ver histórico de custos**
```bash
# Abrir no navegador
gcloud beta billing accounts describe \
  --format="value(displayName)" \
  $(gcloud beta billing projects describe spark-streaming-gcp-terraform --format="value(billingAccountName)")

# Link direto:
# https://console.cloud.google.com/billing
```

### Soluções

**A. Sempre destruir recursos após testes**
```bash
cd terraform/environments/dev
terraform destroy \
  -var="project_id=spark-streaming-gcp-terraform" \
  -auto-approve
```

**B. Configurar auto-delete agressivo**
```hcl
# terraform/modules/dataproc/main.tf
lifecycle_config {
  idle_delete_ttl = "1800s"  # 30 minutos de idle
}
```

**C. Configurar Budget Alerts (proteção)**
```bash
# Criar alerta de $10/mês
gcloud billing budgets create \
  --billing-account=$(gcloud beta billing projects describe spark-streaming-gcp-terraform --format="value(billingAccountName)") \
  --display-name="Spark Streaming Alert" \
  --budget-amount=10USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100
```

**D. Limpar dados antigos do GCS**
```bash
# Deletar checkpoints com mais de 7 dias
gsutil -m rm -r gs://spark-streaming-gcp-terraform-data-lake/checkpoints/**/$(date -d '7 days ago' +%Y%m%d)*

# Deletar logs antigos
gsutil -m rm -r gs://spark-streaming-gcp-terraform-data-lake/logs/**/$(date -d '30 days ago' +%Y%m%d)*
```

---

## 6. Checkpoint location inacessível

### Sintoma
```
java.io.IOException: No FileSystem for scheme: gs
org.apache.spark.sql.streaming.StreamingQueryException: Failed to access checkpoint location
```

### Causa
Conector GCS não está configurado ou caminho do checkpoint está incorreto.

### Solução

**A. Verificar configuração do checkpoint**
```python
# app/config.py - DEVE SER assim:
CHECKPOINT_LOCATION = (
    f"gs://{GCS_BUCKET}/checkpoints/sentiment_job_v1"
    if IS_DATAPROC
    else "/data/checkpoints/sentiment_job_v1"
)

# ❌ NUNCA use file:// no GCP
# CHECKPOINT_LOCATION = "file:///tmp/checkpoints"
```

**B. Verificar se conector GCS está instalado**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --command="ls -la /usr/lib/hadoop/lib/gcs-connector-*.jar"
```

Se não existir, o Dataproc está corrompido (recrear cluster).

**C. Validar acesso ao GCS no Spark**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a

# Dentro da VM, testar Spark + GCS:
/usr/lib/spark/bin/spark-shell --master yarn

# No shell Spark:
val df = spark.read.text("gs://spark-streaming-gcp-terraform-data-lake/README.md")
df.show()
```

**D. Limpar checkpoints corrompidos**
```bash
# Se o job falhou anteriormente, limpar checkpoints antigos
gsutil -m rm -r gs://spark-streaming-gcp-terraform-data-lake/checkpoints/sentiment_job_v1/
```

---

## 7. Component hive-metastore/hive-server2 failed

### Sintoma
```
Error code 13: Component hive-metastore failed to activate
Error code 13: Component hive-server2 failed to activate post-hdfs
```

### Causa
Configuração de hardware insuficiente para iniciar o Hive (componente pesado).

### Solução

**A. Usar máquina com pelo menos 4 vCPUs**
```hcl
# terraform/environments/dev/terraform.tfvars
master_machine_type = "e2-standard-4"  # 4 vCPUs, 16GB RAM
```

**Rationale**: O Hive Metastore requer mínimo de 4 vCPUs para inicializar de forma estável em single-node clusters.

**B. Alternativa: Desabilitar Hive completamente**

Se você NÃO usa SQL/Hive no Spark:

```hcl
# terraform/modules/dataproc/main.tf
override_properties = {
  "dataproc:dataproc.components.activate" = "SPARK,HDFS,YARN,MAPREDUCE,GCS_CONNECTOR"
  "spark:spark.sql.catalogImplementation" = "in-memory"
  "spark:spark.sql.hive.metastore.version" = ""
}
```

**C. Aumentar timeout de inicialização**
```hcl
# terraform/modules/dataproc/main.tf
initialization_action {
  script      = "gs://${var.staging_bucket_name}/scripts/bootstrap.sh"
  timeout_sec = 900  # 15 minutos (padrão é 300s)
}

timeouts {
  create = "45m"  # Timeout do Terraform (padrão é 30m)
}
```

**D. Ver logs específicos do Hive**
```bash
CLUSTER_UUID=$(gsutil ls gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/ | tail -1)
gsutil cat ${CLUSTER_UUID}spark-sentiment-dev-m/dataproc-post-hdfs-startup-script_output | grep -i hive
```

---

## Logs Úteis

### Logs do Cluster

**1. Logs do job Spark (driver)**
```bash
# Durante execução do job
gcloud dataproc jobs wait JOB_ID \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform

# Ver logs de job específico
gcloud dataproc jobs describe JOB_ID \
  --region=us-central1 \
  --format="value(driverOutputResourceUri)"
```

**2. Logs do YARN (executor)**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --command="sudo journalctl -u google-dataproc-agent -f"
```

**3. Logs do sistema (dmesg)**
```bash
gcloud compute ssh spark-sentiment-dev-m \
  --zone=us-central1-a \
  --command="sudo dmesg | tail -100"
```

### Logs do GCS

**1. Listar checkpoints**
```bash
gsutil ls -r gs://spark-streaming-gcp-terraform-data-lake/checkpoints/
```

**2. Ver últimos arquivos modificados**
```bash
gsutil ls -l gs://spark-streaming-gcp-terraform-data-lake/logs/ | sort -k2 | tail -20
```

**3. Baixar logs para análise local**
```bash
mkdir -p ./debug_logs
gsutil -m cp -r gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/ ./debug_logs/
```

---

## Comandos de Emergência

### 1. Forçar parada de job travado
```bash
# Listar jobs ativos
gcloud dataproc jobs list \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform \
  --filter="status.state=ACTIVE"

# Matar job específico
gcloud dataproc jobs kill JOB_ID \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform
```

### 2. Deletar cluster manualmente (fora do Terraform)
```bash
gcloud dataproc clusters delete spark-sentiment-dev \
  --region=us-central1 \
  --project=spark-streaming-gcp-terraform \
  --quiet
```

### 3. Limpar state do Terraform (cluster órfão)
```bash
cd terraform/environments/dev

# Remover do state sem deletar recurso real
terraform state rm module.dataproc.google_dataproc_cluster.spark_cluster

# Reimportar cluster existente
terraform import \
  module.dataproc.google_dataproc_cluster.spark_cluster \
  projects/spark-streaming-gcp-terraform/regions/us-central1/clusters/spark-sentiment-dev
```

### 4. Forçar recriação de um recurso
```bash
# Marcar recurso para recriação no próximo apply
terraform taint module.dataproc.google_dataproc_cluster.spark_cluster

# Aplicar mudanças (vai destruir e recriar)
terraform apply -var="project_id=spark-streaming-gcp-terraform"
```

### 5. Reset completo do projeto
```bash
# ⚠️ CUIDADO: Isso deleta TUDO
cd terraform/environments/dev
terraform destroy -var="project_id=spark-streaming-gcp-terraform" -auto-approve

# Limpar GCS (opcional - preserva dados)
# gsutil -m rm -r gs://spark-streaming-gcp-terraform-data-lake/**

# Reiniciar do zero
terraform init -upgrade
terraform plan -var="project_id=spark-streaming-gcp-terraform"
terraform apply -var="project_id=spark-streaming-gcp-terraform" -auto-approve
```

### 6. Criar snapshot do cluster (antes de destruir)
```bash
# Salvar configuração atual
gcloud dataproc clusters export spark-sentiment-dev \
  --region=us-central1 \
  --destination=cluster-backup-$(date +%Y%m%d).yaml
```

---

## 🆘 Quando Pedir Ajuda

Se nenhuma das soluções acima resolver, colete estas informações antes de abrir um ticket:

```bash
# 1. Versão do Terraform
terraform version

# 2. Versão do gcloud
gcloud version

# 3. Status do cluster
gcloud dataproc clusters describe spark-sentiment-dev \
  --region=us-central1 \
  --format=json > cluster-status.json

# 4. Logs completos do bootstrap
CLUSTER_UUID=$(gsutil ls gs://spark-streaming-gcp-terraform-data-lake/google-cloud-dataproc-metainfo/ | tail -1)
gsutil cat ${CLUSTER_UUID}spark-sentiment-dev-m/dataproc-initialization-script-0_output > bootstrap-logs.txt

# 5. Terraform state
cd terraform/environments/dev
terraform show -json > terraform-state.json

# Enviar arquivos: cluster-status.json, bootstrap-logs.txt, terraform-state.json
```

---

## 📚 Referências

- [Dataproc Troubleshooting Official](https://cloud.google.com/dataproc/docs/support/troubleshooting)
- [Dataproc Init Actions](https://cloud.google.com/dataproc/docs/concepts/configuring-clusters/init-actions)
- [Spark Structured Streaming Guide](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [GCS Connector for Spark](https://cloud.google.com/dataproc/docs/concepts/connectors/cloud-storage)

---

**Última revisão**: Dezembro 2024  
**Mantenedor**: SRE Team - Spark Streaming Project