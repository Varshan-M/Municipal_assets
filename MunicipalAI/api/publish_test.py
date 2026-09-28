import os, json, time, uuid
import paho.mqtt.client as mqtt
from dotenv import load_dotenv

load_dotenv()
MQTT_BROKER = os.getenv("MQTT_BROKER")
MQTT_PORT = int(os.getenv("MQTT_PORT", "8883"))
MQTT_USER = os.getenv("MQTT_USER")
MQTT_PASS = os.getenv("MQTT_PASS")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"test_{uuid.uuid4().hex}")
client.tls_set()
client.username_pw_set(MQTT_USER, MQTT_PASS)

connected = False

def on_connect(client, userdata, flags, reason_code, properties):
    global connected
    print("Connected!", reason_code)
    connected = True
    
def on_publish(client, userdata, mid, reason_codes, properties):
    print("Publish success!")

client.on_connect = on_connect
client.on_publish = on_publish
client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_start()

while not connected:
    time.sleep(0.1)

print("Publishing now...")
payload = json.dumps({"device_id": "python_test_scanner", "distance_cm": 15.42})
client.publish("building/scanner/distance", payload, qos=1)

time.sleep(5)
client.loop_stop()
