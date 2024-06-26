from collections import namedtuple

GFXfont = namedtuple("GFXfont", ["bitmap", "glyph", "intervals",
                                 "interval_count", "compressed", "advance_y",
                                 "ascender", "descender"])

UnicodeInterval = namedtuple("UnicodeInterval", ["first", "last", "offset"])

GFXglyph = namedtuple("GFXglyph", ["width", "height", "advance_x", "left",
                                   "top", "compressed_size", "data_offset"])

fa20Bitmaps = [
    0x78, 0x9C, 0x5D, 0x52, 0x3B, 0x4F, 0x02, 0x41, 0x10, 0x5E, 0x40, 0x14, 0xDF, 0xF7, 0x0F, 0xBC,
    0x18, 0x5B, 0x1F, 0x3D, 0xF1, 0xD1, 0x19, 0x63, 0xA2, 0x24, 0xFE, 0x00, 0xB0, 0xB1, 0x31, 0x11,
    0x63, 0x67, 0x05, 0x9D, 0x9D, 0xD8, 0x9B, 0x08, 0x8D, 0xA5, 0xD1, 0xDA, 0x46, 0x63, 0x6B, 0x21,
    0xB1, 0xD1, 0xCA, 0xA3, 0xA2, 0xB1, 0x40, 0x14, 0x50, 0x38, 0xB8, 0xCF, 0x99, 0xDB, 0xC7, 0x71,
    0xF7, 0xE5, 0xB2, 0xB3, 0xFB, 0xED, 0xDC, 0xCC, 0x37, 0xB3, 0x23, 0x84, 0x84, 0xB5, 0x77, 0xB0,
    0x10, 0x13, 0x21, 0x58, 0xD7, 0x20, 0x34, 0xB6, 0x86, 0x39, 0xBB, 0x07, 0x89, 0xF3, 0x21, 0xBF,
    0x2E, 0x34, 0x8E, 0x0C, 0xD9, 0xA6, 0xD3, 0xCB, 0xE5, 0xD9, 0xBD, 0x47, 0x76, 0x51, 0x71, 0x45,
    0xDA, 0x1F, 0x72, 0x92, 0x95, 0x77, 0x8A, 0x9B, 0x90, 0x24, 0x05, 0x4C, 0xAB, 0xFB, 0x3A, 0x90,
    0xF7, 0x37, 0x17, 0xC0, 0x8E, 0x89, 0xF4, 0x07, 0x8C, 0xB0, 0xED, 0xC0, 0x89, 0xB3, 0x82, 0x53,
    0x3E, 0x64, 0x80, 0x25, 0x32, 0x1B, 0xC0, 0x14, 0x1F, 0x6B, 0x48, 0xB1, 0xF9, 0x81, 0x43, 0x6B,
    0x15, 0x8E, 0x5F, 0x49, 0x53, 0xDE, 0x91, 0x6B, 0x8A, 0xFF, 0x5E, 0xF6, 0xA3, 0x7D, 0x4B, 0x52,
    0xFC, 0x62, 0x4E, 0x08, 0x0F, 0x63, 0x21, 0xB2, 0x8A, 0xB2, 0xC8, 0xA1, 0x21, 0x42, 0x24, 0xE5,
    0x88, 0x3D, 0x2A, 0x61, 0x86, 0x14, 0x2E, 0x46, 0x9B, 0x98, 0x8D, 0x90, 0x6D, 0x4C, 0xD2, 0x17,
    0x21, 0xC9, 0xAD, 0x8B, 0xD1, 0x08, 0x79, 0x87, 0x5D, 0x17, 0x89, 0x08, 0x59, 0x44, 0x7E, 0x80,
    0x58, 0x84, 0x3C, 0x46, 0xC1, 0x83, 0xD0, 0xE4, 0x9A, 0xDC, 0x64, 0x50, 0xD6, 0x32, 0x29, 0xBE,
    0x2C, 0x9E, 0x84, 0xDE, 0x1A, 0xCF, 0x0A, 0xE0, 0x24, 0xA4, 0x67, 0xA9, 0xAF, 0x63, 0x52, 0xD1,
    0x28, 0xA9, 0x98, 0x26, 0xBB, 0xB0, 0xFB, 0xC0, 0xAA, 0xDF, 0xF4, 0x6C, 0x57, 0xF5, 0xC3, 0x77,
    0x01, 0x7B, 0x54, 0xB1, 0xDE, 0xD2, 0x4A, 0x08, 0x4F, 0x7E, 0x2E, 0xAA, 0xE8, 0x8B, 0xDB, 0xA7,
    0xD1, 0xE1, 0x07, 0xEA, 0x60, 0xA2, 0x22, 0xA3, 0x4B, 0x58, 0x9B, 0xB4, 0x0C, 0x90, 0xA4, 0xF6,
    0x87, 0xE7, 0x2A, 0x07, 0xF0, 0xC5, 0x78, 0x88, 0xAC, 0xA1, 0x20, 0x44, 0x0B, 0xD9, 0x10, 0xD9,
    0xC3, 0x0C, 0x77, 0xCA, 0x28, 0x95, 0x3D, 0xE2, 0x5E, 0xDA, 0x9E, 0xFF, 0xFC, 0x81, 0x80, 0x07,
    0x36, 0x2D, 0x35, 0x29, 0x3E, 0x68, 0x86, 0xA6, 0x55, 0x3A, 0xA3, 0xCA, 0x76, 0xD1, 0x88, 0xEB,
    0x4E, 0xA8, 0x59, 0xE5, 0xE9, 0x55, 0x5D, 0xA5, 0x97, 0xC6, 0x15, 0x47, 0xD8, 0x77, 0x69, 0x78,
    0xB5, 0xEA, 0x57, 0x1E, 0xEC, 0x8F, 0xE7, 0x01, 0x9B, 0x40, 0x74, 0xDD, 0xCC, 0x7C, 0x5A, 0x04,
    0x78, 0x53, 0xDC, 0x76, 0xA8, 0x8E, 0x93, 0x4F, 0xA2, 0x6E, 0x92, 0x22, 0x02, 0x6B, 0x3E, 0xD8,
    0xFF, 0x03, 0x94, 0x53, 0x14, 0x87,
]

fa20Glyphs = [
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 406, data_offset =    0), # 
]

fa20Intervals = [
    UnicodeInterval(first = 61463, last = 61463, offset =  0),
]

fa20 = GFXfont(
    bitmap = fa20Bitmaps,
    glyph = fa20Glyphs,
    intervals = fa20Intervals,
    interval_count = 1,
    compressed = True,
    advance_y = 42,
    ascender = 37,
    descender = -6,
)
