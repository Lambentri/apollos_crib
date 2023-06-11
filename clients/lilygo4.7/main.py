import network
import time
import ujson
from epd import EPD47
from umqtt.simple import MQTTClient

from RobotoCondensedLight20 import RobotoCondensedLight20 as Roboto20L
from FontAwesomeFreeSolid20 import fa20 as fa20s
from FontAwesomeFreeRegular20 import fa20 as fa20r
from fb2 import FrameBuffer2

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

WIDE_TYPES = ["gtfs", "tidal", "calendar"]
X2_OFFSET = 450

def sub_cb(topic, msg):
    res = ujson.loads(msg)

    x_ = 50
    i = 0
    xp = 0

    buffer = bytearray(int(PANEL_W * PANEL_H / 2))
    fb = FrameBuffer2(buffer, PANEL_W, PANEL_H)
    fb.fill(0)

    blanks = []

    for k, v in res.items():
        type, id = k.split('-')
        if not v:
            # handle empty arrays somewhere finally
            continue
        for idx, item in enumerate(v):
            if not item:
                continue

            if type in WIDE_TYPES:
                if xp != 0:
                    xp = 0
                    i += 1
                    # TODO, mark these coords as blanks to post-fill later?
                    blanks.append([x+X2_OFFSET,y])
            else:
                pass

            # if we have an available blank space, backtrack and use it
            if type not in WIDE_TYPES and blanks:
                x,y = blanks.pop()
                blank_used = True
                print(f"BU {x}{y}")
            else:
                x = x_ + X2_OFFSET * xp
                y = i * 80 + 25
                blank_used = False
            try:
                if type == "gtfs":
                    fb.box_icon_gtfs(Roboto20L, fa20s, fa20r, item, x, y)
                elif type == "gbfs":
                    fb.box_icon_gbfs(Roboto20L, fa20s, item, x, y)
                elif type == "aqi":
                    fb.box_icon_aqi(Roboto20L, fa20s, item, x, y)
                elif type == "weather":
                    fb.box_icon_weather(Roboto20L, fa20s, item, x, y)
                elif type == "ephem":
                    fb.box_icon_ephem(Roboto20L, fa20s, item, x, y)
                elif type == "calendar":
                    fb.box_icon_calendar(Roboto20L, fa20s, item, x, y)
                elif type == "tidal":
                    fb.box_icon_tidal(Roboto20L, fa20s, item, x, y)
                elif type == "cronos":
                    fb.box_icon_cronos(Roboto20L, fa20s, item, x, y)
                else:
                    print("received unknown type")

                if not blank_used:
                    if type in WIDE_TYPES:
                        i+=1
                    else:
                        if xp == 0:
                            xp = 1
                        else:
                            xp = 0
                            i+=1
            except Exception as e:
                print(e)
                continue

    e = EPD47()
    e.power(True)
    e.clear()
    e.bitmap(buffer, 0, 0, PANEL_W, PANEL_H)
    del e

def main(server=config.MQTT_HOST):
    c = MQTTClient(config.MQTT_USER, server=server, user=config.MQTT_USER,
                   password=config.MQTT_PASS)
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
