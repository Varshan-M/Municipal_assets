import paho.mqtt.client as mqtt
import time

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.connect("broker.hivemq.com", 1883, 60)
client.loop_start()

time.sleep(1)
client.publish("building/scanner/distance", '{"device_id": "test", "distance_cm": 99.9}', qos=1)
print("Published!")
time.sleep(2)
client.loop_stop()
