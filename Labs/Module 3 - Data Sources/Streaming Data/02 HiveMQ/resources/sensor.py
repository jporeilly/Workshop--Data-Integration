import paho.mqtt.client as mqtt
import json
import random
import time

# MQTT broker configuration
broker_address = "localhost"
broker_port = 1883
client_id = "industrial_robot"

# Sensor data generation parameters
robot_id = "robot_1"
loading_factor = 0.75
force_torque = [random.uniform(-10, 10), random.uniform(-10, 10), random.uniform(-10, 10)]
vibration = random.uniform(0, 1)
lidar_detection = [{"x": random.uniform(-10, 10), "y": random.uniform(-10, 10), "z": random.uniform(-10, 10)} for _ in range(10)]

# MQTT client initialization
client = mqtt.Client(client_id=client_id)
client.connect(broker_address, broker_port)

while True:
    # Sensor data generation
    timestamp = int(time.time() * 1000)
    temperature = random.uniform(20, 30)
    position = {"x": random.uniform(-10, 10), "y": random.uniform(-10, 10), "z": random.uniform(-10, 10)}

    # Data packaging into JSON format
    data = {
        "timestamp": timestamp,
        "temperature": temperature,
        "robot_id": robot_id,
        "loading_factor": loading_factor,
        "force_torque": force_torque,
        "vibration": vibration,
        "position": position,
        "lidar_detection": lidar_detection
    }
    json_data = json.dumps(data)

    # MQTT publishing
    client.publish("industrial_robot/data", json_data)

    # Wait for a short period before generating next data
    time.sleep(1)
