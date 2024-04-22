import paho.mqtt.client as mqtt
import json
import random
import time

# MQTT broker configuration
broker_address = "localhost"
broker_port = 1883
topic = "industrial_robot/sensor_data"

# Robot ID
robot_id = "MES_123"

# Connect to MQTT broker
client = mqtt.Client()
client.connect(broker_address, broker_port)

# Generate and publish data continuously
while True:
    # Generate random sensor data
    temperature = round(random.uniform(20, 30), 2)  # Temperature in Celsius
    loading_factor = round(random.uniform(0, 1), 2)  # Loading factor (0-1)
    force_torque = round(random.uniform(-10, 10), 2)  # Force-torque readings (Nm)
    vibration = round(random.uniform(0, 1), 2)  # Vibration (0-1)
    position = [round(random.uniform(-100, 100), 2) for i in range(3)]  # Position (x, y, z) in mm
    lidar_detection = random.choice(["obstacle", "none"])  # LIDAR detection

    # Create JSON payload
    message = {
        "robot_id": robot_id,
        "temperature": temperature,
        "loading_factor": loading_factor,
        "force_torque": force_torque,
        "vibration": vibration,
        "position": position,
        "lidar_detection": lidar_detection
    }

    # Publish JSON payload to MQTT broker
    client.publish(topic, json.dumps(message))

    # Wait for 1 second before generating the next data
    time.sleep(1)