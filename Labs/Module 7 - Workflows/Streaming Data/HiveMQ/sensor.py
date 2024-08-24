# python 3.10
# Note: This script requires the 'paho-mqtt' package to be installed.
# pip3 install paho-mqtt python-etcd for V2
# pip3 install "paho-mqtt<2.0.0" for V1

import random
import time
import json
from paho.mqtt import client as mqtt_client
# username = 'emqx'  not required as HiveMQ has no security
# password = 'public'

# MQTT settings
broker = 'localhost'
port = 1883
topic = "industrial/robot/sensor"
# Generate a Client ID with the subscribe prefix.
client_id = f'python-mqtt-{random.randint(0, 1000)}'

# Connect to MQTT broker
def connect_mqtt():
    def on_connect(client, userdata, flags, rc):
    # For paho-mqtt 2.0.0, you need to add the properties parameter.
    # def on_connect(client, userdata, flags, rc, properties):
        if rc == 0:
            print("Connected to MQTT Broker!")
        else:
            print("Failed to connect, return code %d\n", rc)
    
    # Set Connecting Client ID
    # client = mqtt_client.Client(client_id)

    # For paho-mqtt 2.0.0, you need to set callback_api_version.
    client = mqtt_client.Client(client_id=client_id, callback_api_version=mqtt_client.CallbackAPIVersion.VERSION1)

    # client.username_pw_set(username, password)
    client.on_connect = on_connect
    client.connect(broker, port)
    return client

# Publish sensor data
def publish(client):
    while True:
        temperature = random.uniform(20.0, 100.0)  # Simulate temperature sensor data
        position = {'x': random.uniform(-10.0, 10.0), 'y': random.uniform(-10.0, 10.0), 'z': random.uniform(-10.0, 10.0)}  # Simulate position sensor data
        message = json.dumps({'temperature': temperature, 'position': position})
        result = client.publish(topic, message)
        status = result[0]
        if status == 0:
            print(f"Sent `{message}` to topic `{topic}`")
        else:
            print(f"Failed to send message to topic {topic}")
        time.sleep(1)

# Main function
def run():
    client = connect_mqtt()
    client.loop_start()
    publish(client)

# Execute the main function
if __name__ == '__main__':
    run()
