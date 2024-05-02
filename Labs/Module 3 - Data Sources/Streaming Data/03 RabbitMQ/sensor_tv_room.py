import pika
import random
import time
import json

# RabbitMQ settings
rabbitmq_host = 'localhost'
port = 5672
queue_name = 'tv_room'

# Generate random sensor data
def generate_sensor_data():
    return {
        'temperature': random.uniform(20.0, 100.0),
        'pressure': random.uniform(800.0, 1200.0),
        'humidity': random.uniform(30.0, 80.0)
    }

# Publish sensor data to RabbitMQ
def publish_sensor_data():
    connection = pika.BlockingConnection(pika.ConnectionParameters(host=rabbitmq_host, port=port))
    channel = connection.channel()
    channel.queue_declare(queue=queue_name)

    while True:
        sensor_data = generate_sensor_data()
        message = json.dumps(sensor_data)
        channel.basic_publish(exchange='', routing_key=queue_name, body=message)
        print(f"Sent sensor data: {message}")
        time.sleep(1)

    connection.close()

if __name__ == '__main__':
    publish_sensor_data()
