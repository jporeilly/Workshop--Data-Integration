import paho.mqtt.client as mqtt
import random
import time, datetime
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

# InfluxDB 2 credentials
influx_url = "http://localhost:8086"
influx_token = "59unbLyQ7lyQjHeu1fgVfCwRrqI5HgoaNLac7n-px7-hL2hQ7x4BByyjKx6JavSu07t2ffLpJVHfdsdsyCniew=="
influx_org = "Hitachi-Vantara"
influx_bucket = "sensors"

# MQTT broker credentials
mqtt_broker = "localhost"
mqtt_port = 1883
mqtt_username = 'mosquitto'
mqtt_password = 'mosquitto'
mqtt_topic = "sensors/temperature-humidity"

# Create InfluxDB client and write API
influx_client = InfluxDBClient(url=influx_url, token=influx_token, org=influx_org)
write_api = influx_client.write_api(write_options=SYNCHRONOUS)

# Create MQTT client and connect to broker
mqtt_client = mqtt.Client()
mqtt_client.username_pw_set(mqtt_username, mqtt_password)
mqtt_client.connect(mqtt_broker, mqtt_port)

# Generate and publish sensor data every 10 seconds
while True:
    # Generate random temperature and humidity values between 20 and 30
    temperature = round(random.uniform(20, 30), 2)
    humidity = round(random.uniform(20, 30), 2)

    # Create InfluxDB point and write to database
    point = Point("temperature-humidity") \
        .tag("sensor", "DHT22") \
        .field("temperature", temperature) \
        .field("humidity", humidity) \
        .time(datetime.datetime.utcnow(), WritePrecision.NS)
    write_api.write(influx_bucket, influx_org, point)

    # Publish sensor data to MQTT broker
    mqtt_client.publish(mqtt_topic, f"temperature={temperature},humidity={humidity}")
    
    # Print message to Terminal
    print(f"temperature={temperature},humidity={humidity}")

    # Wait 3 seconds before generating and publishing the next data point
    time.sleep(3)
