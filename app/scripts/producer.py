import time
import json
import random
import logging
from kafka import KafkaProducer
from faker import Faker

# Import absoluto correto
from app.config import settings

# Setup básico de logs
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def create_producer():
    try:
        producer = KafkaProducer(
            bootstrap_servers=settings.KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            # SRE FIX: API Version forçada para evitar erro de handshake no Windows
            api_version=(2, 8, 1),
        )
        logger.info(f"✅ Conectado ao Kafka em {settings.KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except Exception as e:
        logger.error(f"❌ Erro ao conectar no Kafka: {e}")
        return None


def generate_tweet():
    fake = Faker()
    platforms = ["Android", "iPhone", "Web", "API"]

    return {
        "id": fake.uuid4(),
        "user": fake.user_name(),
        "text": fake.sentence(nb_words=random.randint(5, 20)),
        "platform": random.choice(platforms),
        "timestamp": time.time(),
    }


if __name__ == "__main__":
    # CORREÇÃO AQUI: Chamamos create_producer, não create_consumer
    producer = create_producer()

    if producer:
        logger.info(f"🚀 Iniciando stream de tweets para: '{settings.KAFKA_TOPIC_INPUT}'")
        try:
            while True:
                tweet = generate_tweet()
                producer.send(settings.KAFKA_TOPIC_INPUT, tweet)

                logger.info(f"📤 Tweet enviado de @{tweet['user']}")

                # Simula variação de tráfego
                time.sleep(random.uniform(0.1, 0.5))
        except KeyboardInterrupt:
            logger.info("🛑 Parando produtor...")
            producer.close()
