import framebuf1

# matches spacing in fa-intervals
BUS = "\uf207"
BIKE = "\uf206"
TRAIN = "\uf238"
TAXI = "\uf1ba"

CALENDAR = "\uf073"
CLOCK = "\uf017"

CLOUD_SUN = "\uf6c4"
CLOUD = "\uf0c2"
BOLT = "\uf0e7"
WIND = "\uf72e"
CLOUD_RAIN = "\uf73d"
MOON = "\uf186"
SUN = "\uf185"
WATER = "\uf773"

HOUSE = "\uf015"
LUNGS = "\uf604"

CRIB = "\uf66f"
WIFI = "\uf1eb"

CHECK = "\uf00c"
XMARK = "\uf00d"

class FrameBuffer2(framebuf1.FrameBuffer):

    def rrect(self, x: int, y: int, w: int, h: int, color: int, radius: int = 20):
        '''Draw a rounded rectangle with radius

        '''
        self.qcircle(x + radius, y + radius, radius, 255, 3)
        self.hline(x + radius, y, w - radius * 2, color)
        self.qcircle(x + w - radius, y + radius, radius, 255, 0)

        self.qcircle(x + w - radius, y + h - radius, radius, 255, 1)
        self.hline(x + radius, y + h - 1, w - radius * 2, color)
        self.qcircle(x + radius, y + h - radius, radius, 255, 2)

        self.vline(x, y + radius, h - radius * 2, color)
        self.vline(x + w - 1, y + radius, h - radius * 2, color)
        pass

    def qcircle(self, x: int, y: int, r: int, color: int, q=0):
        '''Draw a circle with given center and radius

        Args:
            x: Center-point x coordinate
            y: Center-point y coordinate
            r: Radius of the circle in pixels
            color: The gray value of the line (0-255)
            q: quadrant 0,1,2,3 clockwise starting at midnight
        '''
        f = 1 - r
        ddF_x = 1
        ddF_y = -2 * r
        xx = 0
        yy = r

        self.pixel(x, y + r, color)
        self.pixel(x, y - r, color)
        self.pixel(x + r, y, color)
        self.pixel(x - r, y, color)

        while xx < yy:
            if (f >= 0):
                yy -= 1
                ddF_y += 2
                f += ddF_y
            xx += 1
            ddF_x += 2
            f += ddF_x

            if q == 0:
                self.pixel(x + xx, y - yy, color)  # TH R?
                self.pixel(x + yy, y - xx, color)  # MT R?
            if q == 1:
                self.pixel(x + yy, y + xx, color)  # MB R?
                self.pixel(x + xx, y + yy, color)  # BH R?
            if q == 2:
                self.pixel(x - yy, y + xx, color)  # MB L?
                self.pixel(x - xx, y + yy, color)  # BH L?
            if q == 3:
                self.pixel(x - yy, y - xx, color)  # MT L?
                self.pixel(x - xx, y - yy, color)  # TH L?

    def box_icon_text(self, gfx, gfxicon, icon: str, text: str, x: int, y: int):
        self.rrect(x, y, 420, 70, 255)
        self.text(gfxicon, icon, x+10, y+50)
        self.text(gfx, text, x+90, y+50)

    def box_icon_text_xl(self, gfx, gfxicon1, gfxicon2, icon1: str, icon2: str, text1: str, text2: str, x: int, y: int):
        self.rrect(x, y, 860, 70, 255)
        self.text(gfxicon1, icon1, x+10, y+50)
        self.text(gfxicon2, icon2, x+450, y+50)
        self.text(gfx, text1, x+90, y+50)
        self.text(gfx, text2, x+520, y+50)

    def box_icon_gtfs(self, gfx, gfxicon1, gfxicon2, item, x, y):
        icon1 = BUS # TODO, pull mode from item

        if "live" in item: # TODO
            icon2 = WIFI
        else:
            icon2 = CLOCK
        text1 = f'{item["route"]} to {item["dest"]}'
        text2 = ", ".join([i for i in item["times"][0:2]])

        self.box_icon_text_xl(
            gfx, gfxicon1, gfxicon2, icon1, icon2, text1, text2, x, y
        )

    def box_icon_gbfs(self, gfx, gfxicon, item, x, y):
        text = f"{item["name"]} {item["avail"]}/{item["capacity"]}"
        self.box_icon_text(
            gfx, gfxicon, BIKE, text, x, y
        )

    def  box_icon_aqi(self, gfx, gfxicon, item, x, y):
        text = f"{item["combined"]}"
        self.box_icon_text(
            gfx, gfxicon, LUNGS, text, x, y
        )

    def box_icon_weather(self, gfx, gfxicon, item, x, y):
        icon = CLOUD_SUN # TODO pull me from item
        text = f"{item["temp"]}° and {item["weather"]}"
        self.box_icon_text(
            gfx, gfxicon, icon, text, x, y
        )

    def box_icon_ephem(self, gfx, gfxicon, item, x, y):
        text = f"{item["sunrise"][0:5]}//{item["sunset"][0:5]}"
        self.box_icon_text(
            gfx, gfxicon, SUN, text, x, y
        )

    def box_icon_tidal(self, gfx, gfxicon, item, x, y):
        text1= f"L1: {item["first_l"]} H1: {item["first_h"]} L2: {item["second_l"]} H2: {item["second_h"]}"

        self.box_icon_text_xl(
            gfx, gfxicon, gfxicon, WATER, "", text1, "", x, y
        )

    def box_icon_calendar(self, gfx, gfxicon, item, x, y):
        text1= f"{item["date_start"]}: {item["description"]}"
        self.box_icon_text_xl(
            gfx, gfxicon, gfxicon, CALENDAR, "", text1, "", x, y
        )

    def box_icon_cronos(self, gfx, gfxicon2, item, x, y):
        name = item["name"]
        if item["value"] == True:
            self.box_icon_text(
                gfx, gfxicon2, CLOCK, f"{name}? YES", x, y
            )
        else:
            self.box_icon_text(
                gfx, gfxicon2, CLOCK, f"{name}? NO", x, y
            )

