import os
import time
import json
import random
from faker import Faker
from google.cloud import pubsub_v1

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================
# Pega o ID do projeto da variável de ambiente ou usa o default
PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "spark-streaming-gcp-terraform")
TOPIC_ID = "raw-tweets"

def main():
    # Inicializa o cliente Pub/Sub usando suas credenciais locais (gcloud auth)
    try:
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
    except Exception as e:
        print(f"❌ Erro ao inicializar cliente Pub/Sub: {e}")
        print("Dica: Rode 'gcloud auth application-default login' no terminal.")
        return

    fake = Faker()

    print(f"🚀 Iniciando Producer Pub/Sub")
    print(f"🌍 Projeto: {PROJECT_ID}")
    print(f"📢 Tópico: {topic_path}")
    print("------------------------------------------------")
    print("Pressione Ctrl+C para parar.")

    try:
        while True:
            # 1. Gerar um tweet falso
            tweet = {
                "id": fake.uuid4(),
                "text": fake.text(),
                "created_at": str(fake.date_time_this_year()),
                "user": fake.user_name(),
                "lang": "en"
            }
            
            # 2. Converter para JSON e Bytes (Pub/Sub exige bytes)
            data_str = json.dumps(tweet)
            data = data_str.encode("utf-8")

            # 3. Publicar no tópico
            future = publisher.publish(topic_path, data)
            
            # 4. Esperar confirmação (bloqueante para visualização clara)
            message_id = future.result()
            print(f"📤 Enviado [{message_id}]: {tweet['text'][:50]}...")
            
            # 5. Simular intervalo de tempo real
            time.sleep(random.uniform(0.5, 2.0))
            
    except KeyboardInterrupt:
        print("\n🛑 Producer parado pelo usuário.")
    except Exception as e:
        print(f"\n❌ Erro no envio: {e}")

if __name__ == "__main__":
    main()