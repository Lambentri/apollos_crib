import network
import time
import ujson
from epd import EPD47
from umqtt.simple import MQTTClient
import json
import config

# network
sta_if = network.WLAN(network.STA_IF)
ap_if = network.WLAN(network.AP_IF)
if not sta_if.isconnected():
    sta_if.active(True)
    sta_if.connect(config.WIFI_SSID, config.WIFI_PASSWORD)
    ap_if.active(False)

PANEL_W = 960
PANEL_H = 540

buffer = bytearray(int(PANEL_W * PANEL_H / 2))

def sub_cb(topic, msg):
    print("gottem")
    js = json.loads(msg)
    # pngs = js.get('png')
    # rdr = png.Reader(bytes=pngs)
    # w,h,data,meta = rdr.read()
    # print(list(data))
    print(js)

def main(server=config.MQTT_HOST):
    c = MQTTClient(config.MQTT_USER, server=server, user=config.MQTT_USER,password=config.MQTT_PASS)
    c.set_callback(sub_cb)
    c.connect()
    c.subscribe(config.MQTT_TOPIC)

    while True:
        if True:
            c.wait_msg()
        else:
            c.check_msg()
            time.sleep(1)

    c.disconnect()

if __name__ == "__main__":
    try:
        main()
    except:
        import machine
        machine.reset()