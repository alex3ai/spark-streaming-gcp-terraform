import json
import logging
import sys
from kafka import KafkaConsumer
from kafka.errors import NoBrokersAvailable
from app.config import settings

# Setup de log
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(message)s")
logger = logging.getLogger(__name__)


def create_consumer():
    """
    Cria e retorna um consumidor Kafka configurado.
    Tenta conectar e trata erros iniciais de conexão.
    """
    try:
        # Consumer Group ID:
        # Permite escalar a leitura se necessário.
        # auto_offset_reset='latest': Pula mensagens antigas, foca no "agora".
        consumer = KafkaConsumer(
            settings.KAFKA_TOPIC_OUTPUT,
            bootstrap_servers=settings.KAFKA_BOOTSTRAP_SERVERS,
            auto_offset_reset="latest",
            value_deserializer=lambda x: json.loads(x.decode("utf-8")),
            group_id="sentiment-printer-group",
            # SRE FIX: Força versão para estabilidade no Windows
            api_version=(2, 8, 1),
        )
        logger.info(f" Conectado aos brokers: {settings.KAFKA_BOOTSTRAP_SERVERS}")
        logger.info(f" Ouvindo tópico: {settings.KAFKA_TOPIC_OUTPUT}")
        return consumer
    except NoBrokersAvailable:
        logger.error(f" Erro Crítico: Nenhum broker Kafka disponível em {settings.KAFKA_BOOTSTRAP_SERVERS}.")
        return None
    except Exception as e:
        logger.error(f" Erro desconhecido ao criar consumer: {e}")
        return None


def main():
    consumer = create_consumer()
    if not consumer:
        sys.exit(1)

    print("\n Aguardando mensagens processadas... (Pressione Ctrl+C para parar)\n")
    print("-" * 60)

    try:
        for message in consumer:
            data = message.value

            # Extração segura de campos com valores default
            score = data.get("sentiment_score", 0.0)
            user = data.get("user", "unknown")
            # Trunca texto longo para visualização limpa
            text_raw = data.get("text", "")
            text = (text_raw[:50] + "...") if len(text_raw) > 50 else text_raw

            # Lógica visual para facilitar debug rápido
            if score > 0.05:
                icon = "🟢 POSITIVO"
            elif score < -0.05:
                icon = "🔴 NEGATIVO"
            else:
                icon = "⚪ NEUTRO  "

            # Output formatado alinhado
            print(f"{icon} | Score: {score:>7.4f} | User: {user:<15} | {text}")  # noqa: E231

    except KeyboardInterrupt:
        print("\n Parando consumer a pedido do usuário...")
    finally:
        consumer.close()
        logger.info("Consumer desconectado.")


if __name__ == "__main__":
    main()
