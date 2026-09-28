import paho.mqtt.client as mqtt
import os
from dotenv import load_dotenv

load_dotenv()
MQTT_BROKER = os.getenv("MQTT_BROKER")
MQTT_PORT = int(os.getenv("MQTT_PORT", "8883"))
MQTT_USER = os.getenv("MQTT_USER")
MQTT_PASS = os.getenv("MQTT_PASS")

def on_connect(client, userdata, flags, rc, properties=None):
    print("Connected with code", rc)
    client.subscribe("#")

def on_message(client, userdata, msg):
    print("GOT MESSAGE:", msg.topic, msg.payload)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.tls_set()
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect
client.on_message = on_message

client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_forever()
