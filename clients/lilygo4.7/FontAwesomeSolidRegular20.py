from collections import namedtuple

GFXfont = namedtuple("GFXfont", ["bitmap", "glyph", "intervals",
                                 "interval_count", "compressed", "advance_y",
                                 "ascender", "descender"])

UnicodeInterval = namedtuple("UnicodeInterval", ["first", "last", "offset"])

GFXglyph = namedtuple("GFXglyph", ["width", "height", "advance_x", "left",
                                   "top", "compressed_size", "data_offset"])

fa20Bitmaps = [
    0x78, 0x9C, 0x75, 0x52, 0x3D, 0x2F, 0x43, 0x61, 0x14, 0x3E, 0xB7, 0x3E, 0x5B, 0xD5, 0xDC, 0x44,
    0x22, 0xB6, 0x36, 0x4D, 0xAC, 0x6D, 0x57, 0x11, 0x61, 0x90, 0x18, 0xB5, 0xBF, 0xA0, 0x26, 0x31,
    0x95, 0x89, 0x85, 0x30, 0x11, 0x31, 0x54, 0x44, 0x62, 0xAC, 0xD9, 0x42, 0x22, 0x61, 0x30, 0xB4,
    0x93, 0xB5, 0x65, 0x33, 0x08, 0x06, 0x36, 0xA9, 0xAF, 0xE0, 0xBA, 0x6D, 0x1F, 0xE7, 0xBC, 0xF7,
    0xBE, 0xBD, 0xBD, 0x5A, 0x67, 0x39, 0xE7, 0x7D, 0x9F, 0xF3, 0xF9, 0x9C, 0x43, 0xE4, 0xC9, 0xCD,
    0xED, 0x2A, 0x75, 0x96, 0x39, 0x00, 0x7D, 0x9D, 0xA1, 0x25, 0x86, 0xA2, 0x9D, 0x21, 0xB3, 0x06,
    0x14, 0xFE, 0xC9, 0x48, 0x53, 0x40, 0xC0, 0xFF, 0xB3, 0x77, 0x74, 0x34, 0xE6, 0x58, 0x36, 0x06,
    0xFC, 0x50, 0x03, 0xDA, 0xFB, 0x1D, 0x93, 0x3E, 0x24, 0xC6, 0x08, 0x06, 0x95, 0x79, 0x88, 0xB2,
    0x3F, 0xCA, 0x86, 0xAE, 0xCF, 0x5E, 0x3D, 0x3E, 0x28, 0x35, 0xBD, 0x0F, 0x5C, 0x28, 0xD1, 0xE1,
    0x2D, 0x52, 0x83, 0x96, 0xC5, 0xBF, 0xD0, 0x5B, 0x13, 0xAA, 0xFE, 0x85, 0x3E, 0x9A, 0x50, 0x1B,
    0x57, 0x9C, 0x30, 0x1B, 0x8F, 0xC7, 0xF7, 0xDA, 0xB9, 0x62, 0x1A, 0x70, 0xC7, 0xFA, 0x81, 0x75,
    0xBE, 0x15, 0x30, 0x87, 0x4A, 0x28, 0x03, 0x41, 0x22, 0x0B, 0x39, 0x9E, 0x3E, 0xD6, 0x64, 0xEB,
    0x52, 0x2A, 0x24, 0xBF, 0x90, 0xA5, 0x14, 0x8F, 0x55, 0xC3, 0x33, 0xE0, 0xEE, 0xED, 0x51, 0x15,
    0x0F, 0x9E, 0xA0, 0x6A, 0x70, 0x30, 0x73, 0x25, 0x92, 0x13, 0x64, 0xC3, 0xE9, 0x2B, 0x60, 0x36,
    0x10, 0xFE, 0x44, 0x52, 0xF7, 0xCA, 0xD9, 0xE9, 0x5B, 0x59, 0x05, 0xE9, 0x3F, 0xDF, 0x40, 0x70,
    0xCA, 0x1D, 0xA1, 0xE0, 0xF4, 0xB6, 0x63, 0xB1, 0x37, 0xED, 0xCA, 0xBC, 0x86, 0xF4, 0x98, 0x3D,
    0x87, 0x70, 0x59, 0x01, 0x26, 0x98, 0x5F, 0x89, 0xAF, 0x0B, 0x4B, 0x96, 0x40, 0x74, 0x0D, 0x44,
    0x38, 0x4D, 0xD5, 0x48, 0x39, 0xEB, 0x62, 0xB2, 0xC2, 0x04, 0x14, 0x65, 0xC2, 0x3A, 0xE3, 0x16,
    0x66, 0xE9, 0x04, 0x77, 0xF3, 0x2C, 0x67, 0x40, 0x57, 0x1A, 0x18, 0x01, 0x7A, 0xB9, 0xCF, 0x63,
    0x86, 0x23, 0x1E, 0xB7, 0x05, 0xE9, 0xD7, 0xF8, 0xE2, 0xAF, 0x12, 0xD3, 0xDC, 0x40, 0xC8, 0xE3,
    0x36, 0xCA, 0x6B, 0xAE, 0xD2, 0x3D, 0xD6, 0xA5, 0x27, 0x92, 0x09, 0x2A, 0x1A, 0xEA, 0x95, 0xDC,
    0x7C, 0xAA, 0x79, 0x89, 0xE6, 0x84, 0x61, 0x32, 0x97, 0x57, 0xB6, 0x80, 0xB5, 0x95, 0x19, 0x35,
    0x81, 0x41, 0x3F, 0x09, 0x76, 0x01, 0xF7, 0x1D, 0x75, 0xA9, 0xEF, 0x17, 0xBD, 0x24, 0x03, 0x99,
    0x44, 0x2F, 0x4C, 0xD9, 0x27, 0x8A, 0xF2, 0x55, 0x02, 0xBA, 0xDD, 0xBB, 0x89, 0x88, 0xB6, 0xB8,
    0xDE, 0xAB, 0xE3, 0xFE, 0xA3, 0xD6, 0xA5, 0x76, 0x5A, 0x34, 0x54, 0x70, 0x52, 0xEA, 0x95, 0x47,
    0x63, 0x4F, 0x42, 0x81, 0xBE, 0x84, 0x5C, 0x20, 0x53, 0x53, 0xFC, 0xEA, 0x5B, 0x0A, 0x39, 0xD0,
    0xAE, 0xFB, 0x94, 0x24, 0x57, 0x8E, 0x59, 0xD4, 0x8B, 0xB5, 0x9D, 0x77, 0x42, 0xB6, 0x6F, 0x37,
    0xF7, 0x43, 0xDE, 0xFE, 0xCA, 0x86, 0xD8, 0x69, 0x66, 0x1C, 0xE3, 0xDE, 0xA5, 0x9C, 0x4A, 0x3A,
    0xF7, 0xBC, 0x63, 0x9B, 0xDB, 0xC3, 0xAD, 0x57, 0x94, 0x39, 0x58, 0x50, 0x77, 0xF3, 0x0B, 0x4D,
    0x79, 0x97, 0x94, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x03, 0xC5, 0x90, 0xD4, 0xF4, 0x30, 0x53, 0x26,
    0x06, 0x04, 0x50, 0x98, 0xF6, 0xE7, 0x3F, 0x04, 0xEC, 0x8B, 0x80, 0x89, 0x35, 0xFE, 0xFD, 0x8F,
    0x00, 0xFB, 0x59, 0xC1, 0x62, 0x13, 0xFE, 0xA3, 0x80, 0xF7, 0x20, 0x51, 0x85, 0xBF, 0xA8, 0x82,
    0xFF, 0xD7, 0x03, 0x05, 0x2F, 0x80, 0x59, 0x67, 0xC0, 0xE0, 0x0E, 0x98, 0xCD, 0xC1, 0xC0, 0xF0,
    0x05, 0x44, 0xFB, 0x43, 0x8D, 0xFF, 0x09, 0xE2, 0xF0, 0x31, 0x30, 0x7C, 0x03, 0xD1, 0xF6, 0x50,
    0xC1, 0x1F, 0x20, 0x0E, 0x3F, 0x54, 0xF0, 0xFD, 0x2A, 0x30, 0xD8, 0x05, 0xD6, 0x2E, 0x0F, 0x15,
    0x44, 0x01, 0x38, 0x04, 0x37, 0x02, 0x49, 0x1B, 0x90, 0x71, 0x05, 0xFF, 0xC1, 0x9E, 0xFC, 0x0A,
    0x34, 0x8B, 0xE3, 0x37, 0x50, 0x90, 0x11, 0x49, 0xB0, 0x00, 0xC8, 0xCF, 0x07, 0xE2, 0xFB, 0x0C,
    0x48, 0x82, 0x06, 0x20, 0xE7, 0xA3, 0x0B, 0x2A, 0xD0, 0x4A, 0xF0, 0x2F, 0x16, 0xC1, 0xFE, 0x2F,
    0x58, 0x04, 0x65, 0x05, 0x7E, 0x62, 0xB8, 0x33, 0x1E, 0xEC, 0x77, 0x26, 0x54, 0x1F, 0x41, 0x02,
    0xC4, 0x16, 0x21, 0x28, 0xF0, 0x8D, 0xB4, 0xA0, 0x23, 0x49, 0xB0, 0x1F, 0x14, 0xB2, 0x50, 0xA0,
    0xAB, 0xF0, 0x07, 0x22, 0xC8, 0xC3, 0xD0, 0x00, 0x17, 0x64, 0x66, 0xF8, 0x08, 0x11, 0xE4, 0x60,
    0x08, 0x80, 0x0B, 0x32, 0x30, 0x3C, 0xC0, 0xA3, 0x12, 0xAB, 0x99, 0x58, 0x6C, 0xFF, 0x8A, 0x21,
    0x08, 0x4C, 0x36, 0x9F, 0x30, 0x04, 0x79, 0x18, 0x18, 0x02, 0xD0, 0xD3, 0xE7, 0x7E, 0x50, 0x32,
    0x38, 0x00, 0xD1, 0xC1, 0x00, 0x4D, 0x1F, 0xFF, 0xD9, 0x19, 0x88, 0x15, 0x64, 0x83, 0x65, 0x04,
    0x1E, 0xA8, 0xE0, 0x27, 0xB0, 0xFB, 0x41, 0x81, 0xFD, 0xE7, 0xFF, 0x7B, 0x66, 0xA8, 0x20, 0x30,
    0x32, 0xFA, 0xA1, 0x79, 0xCB, 0x18, 0x91, 0xD3, 0x0C, 0x8D, 0x41, 0x76, 0x03, 0x00, 0x8E, 0x0E,
    0xFC, 0x6F, 0x78, 0x9C, 0x63, 0x60, 0x10, 0x48, 0x2D, 0x87, 0x83, 0x70, 0x66, 0x06, 0x20, 0x10,
    0xF8, 0xF5, 0x1F, 0x09, 0xDC, 0x67, 0x01, 0x0A, 0x3D, 0xF9, 0x8F, 0x02, 0xE6, 0x33, 0x30, 0x18,
    0xFC, 0x47, 0x03, 0x9C, 0x0C, 0x17, 0xD0, 0x85, 0xFC, 0x19, 0xBE, 0x01, 0xF5, 0xEF, 0x86, 0x83,
    0x37, 0x40, 0x1E, 0xC3, 0x9F, 0xFF, 0xEF, 0x99, 0x18, 0x10, 0xE0, 0xE7, 0xFF, 0xFF, 0xCC, 0xFF,
    0xFE, 0xE7, 0x23, 0x89, 0x30, 0x3C, 0xF8, 0xFF, 0x9F, 0xF5, 0xFF, 0x7F, 0x7B, 0x64, 0xA1, 0x03,
    0xFF, 0xFF, 0xB3, 0xA3, 0x09, 0x6D, 0x18, 0x20, 0x21, 0x7F, 0x64, 0xA1, 0x0B, 0x60, 0xA1, 0xF9,
    0xC8, 0x42, 0x9F, 0xC1, 0x42, 0xFF, 0xBD, 0x8C, 0xE1, 0x20, 0xF9, 0x1F, 0x44, 0x08, 0x0D, 0xD0,
    0x44, 0x48, 0xDD, 0xE1, 0x0F, 0x9A, 0x90, 0x3D, 0x38, 0xF4, 0x50, 0x84, 0x38, 0x11, 0xD1, 0x07,
    0x13, 0x62, 0x03, 0xBA, 0x9C, 0xB0, 0x10, 0x37, 0x03, 0x83, 0x03, 0x4C, 0xF6, 0x2F, 0x84, 0x06,
    0xC6, 0xDC, 0x45, 0xA8, 0x10, 0x2B, 0x2C, 0xDD, 0x44, 0x95, 0xFC, 0x83, 0xB2, 0x18, 0x3F, 0xA3,
    0xBB, 0x74, 0x3E, 0xC3, 0x04, 0x74, 0x21, 0x79, 0x06, 0x81, 0x3F, 0x68, 0x42, 0xAC, 0x0C, 0xE8,
    0xCA, 0xEC, 0x40, 0x61, 0xDB, 0xFC, 0x0F, 0x49, 0x24, 0x1A, 0x1C, 0xDC, 0x02, 0x40, 0x77, 0x70,
    0x80, 0x18, 0x0A, 0xFF, 0x20, 0x4E, 0x06, 0xBB, 0xA7, 0x1F, 0x12, 0x17, 0x8F, 0xFE, 0x43, 0x52,
    0x16, 0x5C, 0x11, 0x42, 0x19, 0x42, 0x11, 0x5C, 0xD9, 0x57, 0xA0, 0x47, 0x61, 0x42, 0x0A, 0x7F,
    0xFF, 0x9F, 0x07, 0x51, 0xC6, 0xC2, 0x88, 0x98, 0x05, 0x73, 0x00, 0x20, 0x01, 0xD8, 0xDA, 0x78,
    0x9C, 0xB5, 0xD2, 0x3B, 0x6E, 0xC2, 0x40, 0x10, 0x06, 0xE0, 0x09, 0x26, 0x80, 0x08, 0x8A, 0x72,
    0x00, 0x0A, 0x24, 0x6A, 0x04, 0x82, 0x36, 0x12, 0x47, 0x80, 0x1B, 0xE4, 0x71, 0x01, 0xE8, 0xA8,
    0x10, 0xDC, 0x00, 0x6E, 0x80, 0xE0, 0x02, 0xD0, 0xD3, 0x70, 0x03, 0xB8, 0x01, 0x05, 0x15, 0xD5,
    0x42, 0x94, 0x77, 0x02, 0x7F, 0xC6, 0xBB, 0x6B, 0x7B, 0x56, 0x58, 0x4A, 0x03, 0xBF, 0x64, 0xCB,
    0xFB, 0x49, 0x9E, 0x99, 0x5D, 0x2D, 0x91, 0xCE, 0x73, 0xC7, 0xCF, 0x35, 0xC9, 0x34, 0xA1, 0xA3,
    0xAE, 0x24, 0xAE, 0x0C, 0x22, 0x23, 0x71, 0x67, 0x31, 0xFB, 0x2F, 0xEE, 0x2D, 0xDE, 0x44, 0x74,
    0xB7, 0x45, 0x90, 0x6E, 0x88, 0xEF, 0x88, 0x52, 0xB2, 0xF6, 0x28, 0x0C, 0x2A, 0x61, 0xF0, 0x45,
    0x22, 0x72, 0x06, 0xBF, 0x1D, 0x7C, 0x30, 0x6D, 0x80, 0x75, 0xD2, 0x56, 0x7A, 0x02, 0x96, 0xFA,
    0xA3, 0x0D, 0x94, 0xC3, 0x9E, 0x9F, 0x80, 0xDE, 0xEA, 0x42, 0x8E, 0xC7, 0x03, 0xA7, 0x6D, 0x9F,
    0xE8, 0x74, 0x66, 0xB6, 0x13, 0xFF, 0xE1, 0x1C, 0x97, 0xAE, 0x75, 0xC0, 0x54, 0x6C, 0x18, 0x18,
    0xF0, 0xBB, 0x12, 0x4C, 0x11, 0xCC, 0xB7, 0xE6, 0x77, 0x1F, 0xA8, 0xD7, 0xA2, 0x7C, 0x00, 0x9E,
    0xBB, 0x71, 0x93, 0x7B, 0x1A, 0x9E, 0x18, 0x90, 0x7C, 0x8B, 0xC1, 0xDB, 0x9F, 0x18, 0x6C, 0x1D,
    0x63, 0x70, 0xC4, 0x4F, 0x6A, 0x22, 0x20, 0x35, 0x06, 0xA6, 0x7A, 0xD8, 0x43, 0x68, 0x7A, 0xC1,
    0xD8, 0x90, 0x27, 0xCA, 0x8B, 0x2F, 0x1F, 0x5B, 0x44, 0xBF, 0x21, 0xF6, 0xFC, 0x05, 0xA3, 0xF2,
    0xFA, 0xA2, 0xA6, 0xD7, 0xD6, 0x35, 0xA1, 0x64, 0x67, 0x75, 0x34, 0x78, 0x92, 0x8B, 0xE1, 0x5C,
    0xC6, 0xE2, 0x52, 0x5E, 0xCA, 0xC2, 0x19, 0x90, 0xCF, 0x62, 0x24, 0x91, 0x78, 0x9B, 0xBD, 0x0D,
    0x90, 0x77, 0xF0, 0xD5, 0xBF, 0x5A, 0xD5, 0x22, 0xB9, 0xA9, 0x15, 0xE9, 0x0F, 0x0A, 0x41, 0x05,
    0xFC, 0x78, 0x9C, 0xAD, 0xD2, 0x3B, 0x8A, 0xC2, 0x50, 0x18, 0x05, 0xE0, 0xE3, 0xFB, 0x51, 0xA8,
    0xB5, 0x55, 0x2A, 0x6B, 0x61, 0x16, 0x60, 0x93, 0xCE, 0x42, 0x97, 0x60, 0x21, 0xD1, 0x81, 0xA9,
    0x6D, 0x9D, 0x6A, 0x6A, 0x2B, 0xC1, 0x6A, 0x1A, 0x7B, 0x97, 0xA0, 0x0B, 0x50, 0x71, 0x01, 0x4A,
    0x36, 0x20, 0x88, 0x33, 0x82, 0x8F, 0x51, 0x8F, 0x7F, 0x62, 0x82, 0x8F, 0x1B, 0x21, 0x0E, 0x9E,
    0xE2, 0xDE, 0xCB, 0x07, 0xB9, 0xF9, 0xB9, 0x1C, 0x00, 0xC8, 0xE7, 0x60, 0xA7, 0x1C, 0x81, 0x9B,
    0x0D, 0xCF, 0xE7, 0xC3, 0x22, 0xE0, 0x48, 0x86, 0x4C, 0x59, 0x7B, 0x85, 0x8C, 0x3B, 0xA4, 0x91,
    0x69, 0x6B, 0xFF, 0x24, 0x93, 0x0E, 0xE5, 0x1D, 0x6A, 0xB9, 0xA4, 0xE9, 0x55, 0xB2, 0xA4, 0x4B,
    0xBA, 0x64, 0x51, 0x0F, 0xC9, 0x5F, 0x8E, 0xBC, 0x4D, 0x16, 0xAB, 0x3B, 0x61, 0x1F, 0xFB, 0x7B,
    0x62, 0x48, 0x11, 0x46, 0x55, 0x8A, 0xF9, 0xA3, 0x8E, 0x92, 0x30, 0x7C, 0x65, 0xA6, 0xE4, 0xFF,
    0x43, 0x78, 0x92, 0x69, 0x7C, 0xC9, 0xA1, 0x6E, 0x1C, 0xC8, 0x0F, 0x63, 0x67, 0x53, 0x09, 0xF8,
    0x93, 0x27, 0xB1, 0x9E, 0x29, 0x88, 0x89, 0x4D, 0x05, 0x60, 0xCB, 0x1E, 0xF0, 0x43, 0x02, 0x83,
    0x47, 0xE4, 0xF1, 0xA1, 0x59, 0x6B, 0xCB, 0xF5, 0xEF, 0x8D, 0xAB, 0xEB, 0x5F, 0x39, 0x3D, 0x47,
    0x73, 0x59, 0xC6, 0x53, 0x59, 0xCC, 0xE1, 0x99, 0x9A, 0xD2, 0x22, 0x9A, 0xC0, 0x9A, 0xD2, 0xA9,
    0xE5, 0x13, 0xD3, 0xBB, 0xF4, 0x7B, 0xA1, 0x6F, 0x68, 0x47, 0x2E, 0x82, 0xE2, 0x8C, 0x59, 0xEE,
    0x6F, 0xAE, 0xA8, 0x47, 0x99, 0x3C, 0x2A, 0xA7, 0x14, 0x33, 0x21, 0xF5, 0x7D, 0xBB, 0x89, 0xD4,
    0xF7, 0x04, 0x46, 0x1D, 0x29, 0xF2, 0x78, 0x9C, 0x6D, 0xD3, 0x3B, 0x4E, 0x03, 0x31, 0x10, 0x06,
    0xE0, 0x49, 0x20, 0xE1, 0x25, 0xC8, 0xDE, 0x20, 0x08, 0x51, 0x02, 0x17, 0x40, 0x82, 0xB4, 0x88,
    0x02, 0x24, 0x0E, 0x90, 0x54, 0x94, 0x04, 0x71, 0x81, 0x50, 0x51, 0x02, 0x37, 0x08, 0x0D, 0x25,
    0x82, 0x92, 0x8E, 0xC7, 0x05, 0x82, 0x68, 0x28, 0xD3, 0xD1, 0x50, 0x2C, 0x88, 0x3C, 0x94, 0x90,
    0xEC, 0x30, 0x6B, 0xCF, 0xDA, 0xE3, 0xB5, 0xFF, 0x66, 0x47, 0xDF, 0x7A, 0x6C, 0x79, 0xD7, 0x06,
    0xD0, 0x89, 0x8E, 0x8E, 0xD7, 0x0B, 0xE0, 0x24, 0xBA, 0x45, 0x4A, 0xBC, 0x27, 0x6D, 0x75, 0x8C,
    0x3A, 0x97, 0x62, 0xDC, 0x08, 0xB3, 0x9C, 0x18, 0xEC, 0xA3, 0xCD, 0x26, 0xDB, 0xB9, 0x30, 0x8C,
    0x67, 0x34, 0x8E, 0x25, 0x62, 0x53, 0xD9, 0x35, 0xBA, 0x99, 0x4D, 0x71, 0xA0, 0xEB, 0xEE, 0x05,
    0xE3, 0x16, 0x59, 0x8D, 0xEB, 0x2A, 0x0C, 0xF9, 0x2D, 0xE1, 0x1B, 0xE3, 0x0A, 0xFC, 0x72, 0x35,
    0x6F, 0xBA, 0x05, 0x56, 0x01, 0x12, 0x0F, 0xDB, 0xD0, 0x40, 0x0F, 0xB1, 0xF0, 0x1C, 0xC0, 0xF2,
    0x4F, 0x00, 0x97, 0xFA, 0x01, 0xAC, 0x8C, 0x02, 0x78, 0xF0, 0x17, 0xC0, 0xE6, 0x34, 0x80, 0xAD,
    0xC4, 0xE2, 0x4B, 0x56, 0xB6, 0xD1, 0x62, 0xB6, 0x79, 0xBC, 0x37, 0x23, 0xEB, 0xF4, 0xAB, 0x26,
    0xBA, 0xBC, 0x9A, 0x98, 0xA1, 0x73, 0x00, 0xA7, 0x3C, 0xA7, 0x59, 0x1D, 0x3B, 0x45, 0x80, 0x57,
    0xDD, 0x64, 0x7F, 0x24, 0xB6, 0xE8, 0x43, 0xAA, 0xC6, 0xDD, 0x9E, 0x45, 0xDC, 0xE0, 0xB5, 0x2A,
    0xDF, 0x02, 0x69, 0x5A, 0x35, 0xDB, 0xE2, 0x8D, 0xC4, 0xEE, 0xA3, 0x7A, 0x94, 0x0E, 0xD1, 0x0F,
    0xC0, 0xD4, 0x33, 0x5A, 0xB0, 0xE7, 0x21, 0xED, 0xED, 0xC1, 0xC3, 0x32, 0xED, 0x2D, 0xC9, 0xD9,
    0x53, 0x7A, 0x42, 0xF2, 0xFD, 0xCB, 0x29, 0x36, 0x5C, 0x8B, 0x8B, 0xEA, 0x84, 0x0D, 0x1D, 0xDC,
    0xD1, 0x47, 0xB1, 0x26, 0xAD, 0x93, 0xDD, 0x86, 0x77, 0x81, 0x0B, 0xE6, 0x7C, 0x7F, 0x1A, 0xDB,
    0x16, 0xD7, 0xE3, 0x83, 0x6D, 0xDF, 0xB9, 0x48, 0x67, 0x5F, 0x44, 0x77, 0x25, 0xC8, 0x25, 0x5A,
    0xB3, 0xF5, 0x3F, 0x41, 0x7C, 0x73, 0x93, 0x78, 0x9C, 0x75, 0x93, 0xBD, 0x4E, 0xC3, 0x40, 0x0C,
    0xC7, 0x9D, 0x00, 0x15, 0xB4, 0x01, 0x4E, 0x42, 0x42, 0x42, 0x1D, 0xA8, 0xD8, 0xD8, 0x22, 0x31,
    0xC0, 0x52, 0xD4, 0x27, 0x28, 0x65, 0x82, 0x09, 0xC4, 0xC8, 0x42, 0x59, 0x98, 0xE9, 0xC2, 0x0E,
    0x0C, 0x30, 0x52, 0x1E, 0x00, 0xB1, 0xB0, 0x42, 0xF2, 0x06, 0x74, 0x86, 0x21, 0x42, 0x88, 0x39,
    0x54, 0xA5, 0x88, 0xCF, 0x9A, 0xF3, 0x5D, 0x92, 0xBB, 0xDC, 0x15, 0x0F, 0x17, 0x2B, 0xBF, 0x73,
    0x6C, 0xFF, 0xED, 0x00, 0x70, 0xDB, 0x71, 0xE8, 0x64, 0x05, 0xB0, 0xED, 0xBB, 0x4E, 0x67, 0xFF,
    0x62, 0x08, 0x42, 0x9C, 0x00, 0xB8, 0xC4, 0xC8, 0x26, 0x15, 0xC4, 0xC8, 0xF5, 0x07, 0x88, 0x36,
    0xAA, 0x21, 0x62, 0xF3, 0x83, 0x1F, 0xAE, 0x85, 0xF6, 0x31, 0xB1, 0x31, 0x0B, 0xB5, 0x53, 0x34,
    0x6E, 0xA1, 0x30, 0x45, 0x45, 0xAB, 0x8A, 0x7E, 0x8A, 0xB6, 0x72, 0xC9, 0xD8, 0xD1, 0x83, 0x78,
    0x7B, 0xFB, 0x28, 0x1E, 0x57, 0x1B, 0x0A, 0x75, 0xE4, 0xFD, 0x39, 0x80, 0x53, 0xE9, 0x95, 0x0C,
    0x54, 0x25, 0xF7, 0xD9, 0x40, 0xD4, 0x13, 0xC6, 0x0E, 0x3B, 0xDB, 0x05, 0x5F, 0x20, 0x2D, 0x1D,
    0xB5, 0xBA, 0x06, 0x2F, 0x88, 0x75, 0xE1, 0x36, 0x8D, 0xCA, 0x4B, 0x22, 0xC0, 0xE9, 0x18, 0xF5,
    0x73, 0x01, 0xB1, 0x20, 0x32, 0x16, 0x5B, 0xF4, 0x69, 0xBD, 0xFC, 0x77, 0xC4, 0x91, 0x2E, 0xA1,
    0xA9, 0x46, 0xB4, 0x39, 0x93, 0xEB, 0x98, 0x47, 0xB8, 0x3D, 0x42, 0xF3, 0x95, 0x51, 0x43, 0x0C,
    0x15, 0xC5, 0x05, 0x58, 0xC8, 0xC9, 0x44, 0xB9, 0x42, 0xA9, 0x60, 0xE3, 0x07, 0x03, 0x4D, 0x7D,
    0x7A, 0xEB, 0xC9, 0x0A, 0xD9, 0x17, 0x3F, 0xAF, 0xF3, 0x7D, 0x35, 0xA9, 0xAF, 0x6A, 0xA2, 0x8C,
    0x57, 0x3B, 0x5F, 0x36, 0xD5, 0x10, 0xB7, 0x10, 0x83, 0x5F, 0xC4, 0xB2, 0xD2, 0x70, 0x95, 0x5C,
    0x1F, 0x33, 0x8B, 0x5D, 0xA5, 0xFC, 0x0A, 0x77, 0x5B, 0x0A, 0xA1, 0x47, 0x77, 0x0F, 0xE4, 0xBC,
    0xEE, 0x16, 0xD5, 0xB0, 0x95, 0x94, 0x62, 0xCA, 0xBC, 0xB0, 0x27, 0x0D, 0x05, 0xBA, 0xC2, 0x70,
    0xA3, 0x91, 0x6C, 0x5B, 0x8F, 0xC9, 0xD5, 0x33, 0x21, 0xDE, 0x27, 0x88, 0xEF, 0xE1, 0x36, 0x7C,
    0xE6, 0x50, 0x3C, 0x9B, 0x4D, 0xDA, 0xF3, 0xD1, 0x30, 0x29, 0x18, 0xE3, 0xCB, 0x19, 0x9A, 0xE8,
    0x50, 0x86, 0x71, 0xED, 0x5F, 0x4D, 0x94, 0x2C, 0x09, 0xFF, 0xBF, 0x7A, 0x16, 0x92, 0xAB, 0xB0,
    0xEE, 0x40, 0xDF, 0x42, 0x93, 0xE9, 0x00, 0xDE, 0x2C, 0x34, 0x9D, 0xA2, 0xEE, 0xFF, 0xA8, 0x6D,
    0x21, 0x2F, 0x45, 0x6C, 0x30, 0xBC, 0x31, 0x32, 0xB3, 0x8E, 0x20, 0x23, 0x50, 0x33, 0xC2, 0xCA,
    0xDA, 0x6A, 0x9D, 0xE4, 0xD8, 0x9E, 0xBE, 0x75, 0xC0, 0x96, 0x94, 0xD1, 0x16, 0xFF, 0x01, 0x61,
    0x84, 0x31, 0x72, 0x78, 0x9C, 0x75, 0xD3, 0x3B, 0x0A, 0xC2, 0x40, 0x10, 0x80, 0xE1, 0xF1, 0x11,
    0xD4, 0x46, 0xEC, 0xBC, 0x85, 0x7A, 0x83, 0x78, 0x05, 0x2F, 0xA0, 0xD8, 0xD9, 0x59, 0x59, 0x08,
    0x82, 0xB6, 0x9E, 0x40, 0xAC, 0x04, 0x2F, 0x90, 0xDA, 0x4E, 0x04, 0x3B, 0x21, 0xDE, 0x20, 0x8D,
    0xA0, 0x5D, 0x50, 0x44, 0x31, 0x41, 0xC7, 0xBC, 0x76, 0x93, 0xEC, 0xCE, 0xFC, 0x90, 0xEA, 0x23,
    0x61, 0x77, 0x76, 0x03, 0x10, 0xD7, 0xDB, 0x9D, 0xA6, 0x65, 0xA0, 0xDA, 0x62, 0x90, 0xD3, 0x24,
    0x64, 0x81, 0x51, 0x6E, 0x49, 0x93, 0x86, 0x1F, 0x13, 0x8E, 0x35, 0xDA, 0xA3, 0xA8, 0xA2, 0x92,
    0x27, 0xC9, 0x84, 0xC9, 0xD2, 0xC8, 0x48, 0x57, 0x0A, 0xBA, 0xB7, 0xE0, 0xC9, 0xD8, 0x19, 0xF3,
    0x59, 0x29, 0x3D, 0x15, 0xC2, 0xAA, 0xA4, 0x8F, 0x4A, 0xA6, 0xA4, 0x9F, 0x4A, 0xB6, 0x24, 0x55,
    0x10, 0x0B, 0x62, 0xC3, 0x3A, 0x89, 0xA9, 0x74, 0x78, 0xBA, 0xEA, 0x54, 0x8C, 0xE5, 0xA2, 0x8B,
    0xAB, 0x8D, 0x22, 0x6D, 0x46, 0xEF, 0x37, 0xAA, 0x4F, 0x2F, 0x2F, 0xAA, 0x22, 0x0F, 0x51, 0x6B,
    0x03, 0x70, 0x67, 0x08, 0x0D, 0x78, 0x73, 0x54, 0x07, 0x9F, 0xA3, 0x81, 0x3E, 0x5A, 0x91, 0x45,
    0x8C, 0x36, 0xC9, 0xE5, 0x09, 0xE1, 0xCB, 0x93, 0xC7, 0xD3, 0x8B, 0x13, 0x9B, 0xDF, 0xF2, 0x9C,
    0x1D, 0x14, 0xB6, 0x89, 0x3B, 0x93, 0x54, 0x03, 0x78, 0xD0, 0xE2, 0x84, 0x47, 0x49, 0xBF, 0xD6,
    0x0A, 0xCF, 0xF2, 0x40, 0xAE, 0x2F, 0xBE, 0x6E, 0x47, 0xE2, 0x73, 0xE2, 0x8F, 0x18, 0xAE, 0xD6,
    0xF9, 0x46, 0xD1, 0x8D, 0xFA, 0x03, 0xA9, 0x61, 0xC7, 0xDB, 0x78, 0x9C, 0x5D, 0x92, 0x5D, 0x0E,
    0xC1, 0x40, 0x14, 0x85, 0x8F, 0xA6, 0x84, 0x88, 0xB0, 0x00, 0x0F, 0x4D, 0xBC, 0x23, 0xE9, 0x83,
    0x57, 0x3B, 0xD0, 0x9D, 0x58, 0x82, 0x2E, 0xC1, 0x0E, 0x6A, 0x07, 0x96, 0x50, 0x56, 0x52, 0xC2,
    0x7B, 0xE3, 0x2F, 0x84, 0xEA, 0x75, 0x9B, 0xFE, 0x98, 0xD3, 0xF3, 0xF6, 0x9D, 0x4C, 0xE6, 0x9B,
    0x99, 0x3B, 0x40, 0x15, 0xAF, 0x09, 0x8A, 0xF3, 0x8D, 0x1B, 0x54, 0x9C, 0x45, 0xDA, 0x26, 0x7B,
    0x22, 0xD2, 0x31, 0x8B, 0xA7, 0x16, 0xB6, 0xC1, 0x6B, 0xE5, 0xC8, 0x5C, 0xF0, 0xD1, 0x62, 0x69,
    0xF0, 0x5E, 0x59, 0xFA, 0x86, 0x32, 0x15, 0xDE, 0xF3, 0x94, 0xB1, 0x58, 0xA4, 0x14, 0x09, 0x59,
    0x29, 0xB2, 0x20, 0xA5, 0xA6, 0x47, 0x4A, 0x4D, 0x8B, 0x94, 0x9A, 0xFF, 0x2D, 0x73, 0x0E, 0x58,
    0x29, 0x32, 0x21, 0xA5, 0xA6, 0x4B, 0x4A, 0xCD, 0xCC, 0x75, 0xDD, 0x11, 0xE0, 0x0B, 0x65, 0x88,
    0x2B, 0x17, 0x01, 0xEE, 0x5C, 0x84, 0x38, 0x72, 0xB1, 0xC2, 0x3C, 0xA1, 0xA2, 0x54, 0xA5, 0x05,
    0x6F, 0xEB, 0x67, 0x29, 0xE7, 0xB0, 0x2B, 0xB8, 0x7A, 0xD4, 0x5B, 0x51, 0x54, 0x63, 0x78, 0xE7,
    0x3C, 0x2E, 0x79, 0x90, 0x73, 0x54, 0x8D, 0xD6, 0x67, 0x25, 0x70, 0xE0, 0xF7, 0x00, 0x1E, 0xA4,
    0xD4, 0x24, 0xA4, 0x04, 0xA6, 0xAC, 0x04, 0x36, 0xA4, 0xD4, 0x5C, 0x48, 0xA9, 0x79, 0x91, 0x32,
    0xBF, 0x6A, 0x60, 0xB2, 0x23, 0xB5, 0xDF, 0x06, 0xFE, 0x3A, 0xD9, 0xB9, 0x62, 0x9B, 0x0B, 0x58,
    0x26, 0xFC, 0x00, 0xC8, 0x21, 0x19, 0x71, 0x78, 0x9C, 0x6D, 0x93, 0xB1, 0x4A, 0x03, 0x51, 0x10,
    0x45, 0x67, 0x57, 0x63, 0x14, 0x83, 0x88, 0xAD, 0x85, 0x8B, 0x7E, 0x80, 0x62, 0xB0, 0xF2, 0x23,
    0xB4, 0xD2, 0x4E, 0x05, 0x31, 0xA5, 0xA6, 0xB3, 0xF4, 0x13, 0xF4, 0x0B, 0x4C, 0xC4, 0x0F, 0x08,
    0xD6, 0x16, 0x8A, 0xA5, 0x08, 0x01, 0x6B, 0xC1, 0x80, 0xAD, 0x4D, 0xD0, 0x80, 0x8B, 0xBB, 0x5E,
    0xE7, 0xCD, 0xEE, 0x66, 0xF7, 0xCD, 0xE4, 0x36, 0x8F, 0x3D, 0x6F, 0xB8, 0x73, 0x87, 0x37, 0x4B,
    0x54, 0x6A, 0xF7, 0x7C, 0x7F, 0x8A, 0xB4, 0x52, 0xE0, 0x7D, 0x5A, 0xB1, 0x23, 0xB0, 0x3A, 0x0A,
    0xB6, 0x1D, 0xC4, 0x9C, 0x0F, 0x23, 0x81, 0x3B, 0xAA, 0xF4, 0xF6, 0xFE, 0x93, 0x5D, 0x4D, 0x2B,
    0x8A, 0x01, 0x1B, 0x60, 0x00, 0xD4, 0x0C, 0x7C, 0x04, 0x66, 0x0C, 0x1C, 0x4E, 0xA8, 0xDC, 0x48,
    0x80, 0x80, 0xE8, 0x0E, 0x4A, 0x0F, 0x7C, 0xF7, 0xAB, 0xE1, 0x3A, 0x43, 0xCD, 0xA4, 0x4F, 0xA2,
    0xD8, 0x81, 0xB3, 0x7E, 0xF5, 0xD9, 0x75, 0x20, 0x0D, 0x57, 0xAB, 0x5A, 0xB2, 0x33, 0x96, 0xDA,
    0x6C, 0xFA, 0x0A, 0x99, 0x7D, 0x98, 0xF6, 0xDB, 0xB6, 0x3B, 0x6B, 0xD6, 0xE6, 0x04, 0x7A, 0x76,
    0x22, 0x56, 0xED, 0x66, 0x02, 0x5C, 0x30, 0x69, 0xB8, 0xEA, 0xD0, 0x66, 0x4C, 0x71, 0x19, 0x9D,
    0xB4, 0x58, 0x7B, 0x95, 0x87, 0x89, 0xD1, 0x1B, 0xE5, 0x3E, 0xF5, 0x31, 0x4C, 0xD0, 0x49, 0x73,
    0xD8, 0x0F, 0x73, 0xC6, 0x2B, 0x71, 0xF6, 0xE7, 0xB5, 0x8C, 0x9E, 0xDF, 0x18, 0xAC, 0xC4, 0x05,
    0x94, 0x25, 0x1A, 0x64, 0x56, 0xED, 0x17, 0x27, 0xDE, 0x0C, 0x59, 0x82, 0x6F, 0x71, 0x2A, 0xDC,
    0x47, 0x6E, 0x64, 0xA2, 0x2F, 0x07, 0x97, 0x0B, 0x78, 0x05, 0xCC, 0xF3, 0xD1, 0x65, 0x76, 0x3A,
    0xCE, 0xC1, 0xBB, 0xD9, 0x70, 0xE7, 0x71, 0x6B, 0xAB, 0x4C, 0xDC, 0xCD, 0x2A, 0x3D, 0x2D, 0xFE,
    0x64, 0x9E, 0x15, 0x3D, 0x49, 0x90, 0xD0, 0x87, 0x32, 0xD5, 0x85, 0xCF, 0xB2, 0xB5, 0x6E, 0x28,
    0x47, 0x79, 0x83, 0x40, 0x41, 0x4E, 0xDE, 0xD7, 0xFF, 0x0F, 0x51, 0x73, 0xCD, 0xFF, 0xFE, 0x07,
    0xAB, 0xCC, 0x5E, 0x42, 0x78, 0x9C, 0x9D, 0x93, 0xB1, 0x4E, 0x02, 0x41, 0x10, 0x86, 0x07, 0x15,
    0x89, 0x22, 0x86, 0x10, 0x0B, 0x1B, 0x09, 0x0F, 0x60, 0xA2, 0x2F, 0x60, 0x42, 0x65, 0x0B, 0x89,
    0x0F, 0x80, 0xA5, 0xEF, 0x40, 0x01, 0xB1, 0xB1, 0xA4, 0xA6, 0xC2, 0x37, 0xD0, 0x37, 0xC0, 0x37,
    0x38, 0x13, 0x4B, 0x0B, 0x6D, 0xAC, 0x4F, 0x01, 0x35, 0x87, 0x72, 0xE3, 0xCC, 0xFC, 0xA7, 0xB0,
    0xB7, 0x5B, 0x39, 0xC5, 0x6E, 0xE6, 0xCB, 0xDC, 0xEC, 0xCE, 0xFE, 0xFF, 0x11, 0x69, 0x9C, 0x9D,
    0xAE, 0x51, 0x2E, 0xAA, 0x09, 0x73, 0x54, 0xCC, 0xC1, 0x19, 0x4B, 0x44, 0x05, 0x87, 0xB5, 0xD9,
    0xE2, 0x80, 0x2E, 0x1F, 0xBB, 0x7F, 0x70, 0x0A, 0x38, 0x3E, 0x97, 0xE5, 0xE4, 0x17, 0x7E, 0x01,
    0xF2, 0x42, 0x97, 0x75, 0xB0, 0x63, 0x5E, 0x8D, 0x0A, 0x60, 0xDF, 0x81, 0x3D, 0xC0, 0x6B, 0x07,
    0x8E, 0x01, 0xEF, 0x1C, 0xF8, 0x04, 0x78, 0xEB, 0xC0, 0x08, 0xF0, 0x81, 0xDD, 0xD2, 0x7D, 0xAF,
    0xA5, 0x44, 0x2C, 0x03, 0x7F, 0xE7, 0x21, 0x0F, 0xFC, 0x42, 0x1D, 0x60, 0x1A, 0x80, 0x95, 0x24,
    0x00, 0x5B, 0x7E, 0x4B, 0x69, 0x1A, 0x60, 0x7C, 0x93, 0x06, 0xE0, 0x28, 0xF4, 0x79, 0xEF, 0x33,
    0x00, 0x8F, 0x9E, 0x03, 0x70, 0xAB, 0xE9, 0x33, 0x79, 0xA8, 0x0F, 0x0F, 0x8A, 0x4E, 0x8D, 0xFC,
    0x51, 0x23, 0xD3, 0xE8, 0x6A, 0xB8, 0x1A, 0x17, 0xAE, 0xFE, 0xFF, 0x8C, 0x26, 0xBA, 0xEC, 0x21,
    0xC9, 0xEC, 0x37, 0x29, 0xEB, 0x5A, 0x85, 0xB8, 0x6F, 0x3B, 0x80, 0xF3, 0x16, 0xE4, 0xDF, 0xD0,
    0x2D, 0xE9, 0x64, 0xB6, 0x31, 0x59, 0x27, 0xE6, 0x98, 0x46, 0x26, 0xBC, 0xE8, 0x5E, 0x34, 0x9B,
    0x75, 0x90, 0x6C, 0x2A, 0x9C, 0x99, 0xAB, 0xE4, 0x0D, 0x62, 0x32, 0x5B, 0xEE, 0x92, 0x95, 0x68,
    0x8D, 0xFA, 0x44, 0x6A, 0xE6, 0x96, 0x10, 0x61, 0xDC, 0x57, 0xD9, 0xB6, 0x89, 0xD2, 0x6C, 0x76,
    0x15, 0x05, 0xB0, 0x6C, 0x89, 0x5D, 0x6D, 0x61, 0xA6, 0xBC, 0x97, 0xB4, 0x64, 0x7E, 0x19, 0x28,
    0x7C, 0xB7, 0xDE, 0xF2, 0x37, 0xC4, 0x05, 0x3B, 0xB5, 0xAE, 0xB0, 0x9D, 0x46, 0x3A, 0xDA, 0x0B,
    0x1F, 0x2E, 0x13, 0xB9, 0x30, 0x66, 0xAF, 0x2D, 0x93, 0x1F, 0x17, 0xE1, 0xF3, 0x8E, 0x78, 0x9C,
    0x5D, 0x90, 0xBD, 0x0E, 0x01, 0x41, 0x14, 0x85, 0x47, 0x62, 0x45, 0xFC, 0x84, 0x6A, 0x5B, 0xDE,
    0xC0, 0x1B, 0xA0, 0xD2, 0xDA, 0xC4, 0x0B, 0x78, 0x0D, 0x15, 0x2A, 0xA5, 0x52, 0x74, 0x9E, 0x43,
    0x22, 0xDB, 0x4B, 0xC4, 0x23, 0xAC, 0x42, 0xA3, 0xDA, 0x10, 0x82, 0xD8, 0x75, 0xED, 0xDC, 0x31,
    0x67, 0x67, 0xE6, 0x54, 0xF3, 0xE5, 0xDC, 0x39, 0xF7, 0x47, 0x08, 0xA9, 0xF6, 0x6A, 0x7F, 0xF0,
    0x04, 0x34, 0x4F, 0x89, 0xA8, 0x9E, 0x23, 0x49, 0x95, 0x34, 0x06, 0x5F, 0x89, 0x5D, 0xD8, 0x4F,
    0x89, 0x61, 0x41, 0xE3, 0x86, 0xAB, 0x6B, 0xB0, 0x5F, 0x12, 0x63, 0xD8, 0x01, 0xDB, 0x43, 0xD8,
    0x57, 0xE6, 0x2A, 0xF8, 0xCD, 0x5C, 0xD4, 0xD8, 0x66, 0x8C, 0x60, 0xAB, 0xF4, 0x29, 0xF8, 0xE4,
    0xC4, 0xDD, 0x99, 0x5B, 0x76, 0x77, 0x6A, 0x80, 0x3F, 0x0E, 0xA7, 0xCC, 0x1D, 0x30, 0xEF, 0x46,
    0x3D, 0x30, 0x39, 0xFD, 0x94, 0x1F, 0x82, 0x13, 0x55, 0x80, 0xF5, 0x54, 0x3E, 0x95, 0xAD, 0xE3,
    0x18, 0x03, 0xDD, 0xC8, 0x0E, 0x50, 0xF3, 0xE7, 0x1F, 0x66, 0x64, 0x77, 0x6C, 0xFE, 0x99, 0x2A,
    0x76, 0x20, 0x45, 0x9E, 0x1D, 0x40, 0x47, 0xDF, 0x38, 0x18, 0x6B, 0xB7, 0xDE, 0x66, 0xB1, 0x0F,
    0x32, 0x94, 0x2D, 0x3A, 0x36, 0x59, 0xDE, 0xFD, 0x9C, 0xE3, 0x92, 0x13, 0x12, 0x8D, 0xB1, 0xEA,
    0x11, 0xA4, 0xCE, 0x90, 0xFD, 0x0B, 0xEF, 0xE0, 0xE3, 0x0A, 0x62, 0xB4, 0x98, 0x0C, 0xF8, 0xF1,
    0x03, 0xBE, 0x3B, 0x04, 0xC1, 0x78, 0x9C, 0xAD, 0x92, 0x3F, 0x2C, 0x43, 0x61, 0x14, 0xC5, 0x4F,
    0xF5, 0x29, 0x31, 0xBD, 0x44, 0xA2, 0x83, 0x48, 0x1A, 0x21, 0xC2, 0x20, 0x8F, 0x98, 0x30, 0x34,
    0x91, 0x90, 0x30, 0x68, 0x62, 0x30, 0x54, 0xA2, 0x0C, 0x46, 0xB1, 0x10, 0x89, 0x94, 0x68, 0xC5,
    0xDA, 0x74, 0xB0, 0x35, 0x61, 0xF0, 0x67, 0x30, 0xD4, 0xC0, 0x42, 0xA8, 0x84, 0x41, 0x2C, 0x95,
    0x48, 0x18, 0x19, 0x1B, 0x7F, 0xF2, 0x6C, 0x45, 0xFB, 0x5C, 0xF7, 0x7E, 0xDF, 0x1B, 0xDF, 0xDB,
    0x7A, 0x97, 0x5F, 0xBE, 0x73, 0x9A, 0xBE, 0x7B, 0xCF, 0xBD, 0x00, 0xD0, 0x0C, 0x5D, 0x75, 0x1A,
    0x11, 0x97, 0x78, 0xA4, 0x1E, 0x81, 0x59, 0xB2, 0x1B, 0x84, 0x56, 0xA5, 0xA8, 0x9D, 0x2C, 0x11,
    0x0D, 0xB2, 0xFE, 0x4D, 0x64, 0x87, 0x45, 0x27, 0xDA, 0x08, 0xB0, 0x7E, 0x46, 0x52, 0x57, 0xE7,
    0x8E, 0xE2, 0xE5, 0xBD, 0x42, 0xC1, 0xC0, 0x12, 0x79, 0xD6, 0x2C, 0x5E, 0xBD, 0x8D, 0xA2, 0x32,
    0x2E, 0xF4, 0xE3, 0xA5, 0xA4, 0x99, 0xAF, 0x8A, 0x91, 0x20, 0x1A, 0x42, 0xEA, 0x4F, 0xDE, 0x06,
    0x0E, 0x44, 0x4F, 0x06, 0xA2, 0x55, 0x9A, 0x04, 0xB6, 0x5A, 0xA4, 0xF5, 0x95, 0xD5, 0x4E, 0xD5,
    0xEA, 0xB2, 0xA2, 0xB9, 0x1D, 0x44, 0x6D, 0x2B, 0x32, 0xAD, 0x69, 0x75, 0x69, 0xCE, 0x85, 0x5D,
    0xA3, 0x4C, 0x8B, 0x82, 0x98, 0x43, 0xC3, 0xC2, 0x4D, 0xA2, 0x90, 0xD2, 0x9F, 0xB8, 0xC5, 0xF5,
    0x20, 0xE6, 0xB9, 0x7B, 0x8A, 0x07, 0x90, 0x96, 0xF1, 0xEA, 0x59, 0xFF, 0xF1, 0x9C, 0xBC, 0x11,
    0x7B, 0xDE, 0x91, 0x64, 0xF0, 0xE5, 0x97, 0xD5, 0x03, 0x6F, 0x61, 0x41, 0x47, 0xBE, 0xBB, 0xAF,
    0xC5, 0x99, 0x32, 0xE7, 0x03, 0x8B, 0x8A, 0x21, 0x58, 0x6F, 0x6C, 0xC7, 0xB9, 0xD1, 0x77, 0x8E,
    0xB2, 0x1B, 0xE6, 0x33, 0xF5, 0x72, 0xF7, 0xB2, 0x2D, 0xF4, 0x75, 0xB8, 0x33, 0x0D, 0xA8, 0x67,
    0x7F, 0x8D, 0xA3, 0x42, 0xE2, 0x58, 0xA7, 0x9F, 0x5A, 0x53, 0xFF, 0x8F, 0xD3, 0xB8, 0xFB, 0xBD,
    0x2A, 0x15, 0xC4, 0xE1, 0x33, 0xCA, 0x88, 0x73, 0x4B, 0xD4, 0x2A, 0x7A, 0xF4, 0x57, 0xE6, 0x19,
    0x1B, 0x39, 0x54, 0xEB, 0x1E, 0x9D, 0xBA, 0x13, 0x8E, 0xF3, 0xEF, 0x1D, 0xCF, 0xC9, 0xDB, 0x70,
    0xED, 0x1D, 0x49, 0xDE, 0x3F, 0xAB, 0x13, 0x76, 0xDB, 0xF5, 0x41, 0x4D, 0xC4, 0x64, 0x25, 0x7C,
    0xC0, 0x37, 0x92, 0xAE, 0x59, 0x49, 0xF2, 0x6D, 0xEF, 0x7C, 0xDA, 0x39, 0x3E, 0x23, 0xF3, 0xE8,
    0xC3, 0xCE, 0x19, 0x40, 0xDA, 0x69, 0xF2, 0x9F, 0xEE, 0x1F, 0xE5, 0x8B, 0x7A, 0x92, 0x78, 0x9C,
    0xBD, 0x92, 0x4B, 0x0E, 0xC1, 0x50, 0x14, 0x86, 0xAB, 0x95, 0xA2, 0x0C, 0x24, 0xA6, 0x24, 0x36,
    0x20, 0x91, 0x5C, 0x73, 0x4B, 0x60, 0x07, 0x0C, 0x2C, 0xC0, 0x4E, 0xEC, 0x40, 0x59, 0x01, 0x03,
    0x73, 0x76, 0xD0, 0xA4, 0x2B, 0xB0, 0x83, 0x4E, 0xBC, 0x5F, 0x47, 0xEF, 0xAB, 0x8F, 0x73, 0x4F,
    0x24, 0x12, 0xF1, 0x8F, 0xFE, 0x7C, 0x93, 0xF3, 0xB5, 0xF7, 0xB7, 0xAC, 0x24, 0x13, 0xC7, 0xA2,
    0xB2, 0x00, 0x9F, 0xC2, 0xF5, 0x3B, 0x40, 0x95, 0xE0, 0x21, 0x00, 0x04, 0x05, 0x03, 0x77, 0x5F,
    0x31, 0x87, 0x8E, 0xC1, 0x0F, 0x1C, 0x43, 0x84, 0x4F, 0x8F, 0x41, 0x66, 0x84, 0xF8, 0x45, 0x71,
    0x28, 0x21, 0x47, 0x9D, 0x9C, 0x6B, 0xFD, 0x91, 0x70, 0xF0, 0x90, 0xA3, 0x4E, 0xC6, 0x55, 0x3A,
    0xEA, 0xA4, 0xAE, 0xC7, 0x2C, 0x4E, 0x5D, 0xA7, 0x90, 0xCF, 0x40, 0xF1, 0x2B, 0xE2, 0xE0, 0x22,
    0x47, 0x9D, 0x19, 0x76, 0xCC, 0xBA, 0x86, 0x26, 0xE6, 0xAE, 0x79, 0x47, 0x9D, 0x96, 0xFA, 0x8F,
    0x38, 0x91, 0xFD, 0x24, 0x39, 0x78, 0x34, 0x86, 0xDA, 0x8D, 0xE6, 0xE5, 0x25, 0x79, 0x77, 0x1E,
    0x8B, 0xEE, 0x0C, 0xBA, 0x12, 0xDF, 0xFB, 0x27, 0xEE, 0xF7, 0x18, 0xDB, 0x10, 0xBC, 0xC2, 0xFB,
    0xC3, 0xE4, 0x45, 0xDE, 0x4F, 0x26, 0x77, 0xD2, 0x97, 0xFE, 0x96, 0x6F, 0x7F, 0xC4, 0x3F, 0xDF,
    0x5D, 0x4B, 0x2E, 0xE6, 0x2A, 0x5F, 0x5B, 0x6E, 0x7D, 0x28, 0x7A, 0x20, 0xFA, 0x5E, 0xF4, 0xBE,
    0xDC, 0xE1, 0x99, 0xF7, 0xA6, 0x5C, 0xB6, 0x98, 0x81, 0xAB, 0x06, 0xCA, 0x18, 0x6B, 0xA8, 0xDA,
    0x8E, 0xBB, 0xCD, 0xCB, 0x1B, 0x64, 0xF4, 0x4F, 0x65, 0x78, 0x9C, 0xBD, 0x94, 0x31, 0x4E, 0x02,
    0x41, 0x14, 0x86, 0x1F, 0x22, 0xB8, 0x01, 0x36, 0xD2, 0xD8, 0x58, 0x28, 0xF1, 0x02, 0x52, 0x59,
    0x99, 0x68, 0x6B, 0x81, 0xAC, 0xAD, 0x8D, 0x26, 0x1E, 0x40, 0x6E, 0xA0, 0x37, 0x00, 0x63, 0x4C,
    0xE8, 0xC0, 0x13, 0xC8, 0x09, 0x84, 0xE8, 0x01, 0x6C, 0x2C, 0x4D, 0x88, 0x85, 0xF5, 0xA2, 0x18,
    0x44, 0x70, 0xF9, 0xDD, 0x79, 0x6F, 0x66, 0x76, 0x37, 0x42, 0xEB, 0x14, 0xF0, 0xFF, 0xFB, 0x0D,
    0xF3, 0xF3, 0xDE, 0x1B, 0x20, 0x8A, 0x96, 0x97, 0xA1, 0x45, 0x2B, 0xF0, 0x53, 0x0B, 0xC8, 0x29,
    0xE0, 0x2C, 0x40, 0x97, 0x40, 0x6E, 0x01, 0x6A, 0xFC, 0x0F, 0xF2, 0x9A, 0x6B, 0x06, 0x1D, 0x35,
    0x13, 0xD5, 0x95, 0x67, 0xC0, 0x8A, 0xA0, 0xB0, 0x02, 0x7F, 0x39, 0x86, 0x86, 0x00, 0xEA, 0x82,
    0x46, 0xA1, 0xAC, 0xC6, 0x50, 0x10, 0x7A, 0xA4, 0x15, 0x2A, 0x29, 0x15, 0x6B, 0x4A, 0x43, 0x79,
    0x38, 0x0A, 0xD5, 0x58, 0xE6, 0x12, 0xE7, 0x01, 0x79, 0x85, 0xDA, 0x2C, 0xAB, 0xC9, 0xF3, 0xE0,
    0x76, 0x80, 0x42, 0x8F, 0xA5, 0x6F, 0x88, 0x1C, 0x02, 0x77, 0x00, 0x6C, 0x0A, 0xB2, 0x6D, 0x7E,
    0xD7, 0x68, 0x0A, 0x3C, 0x69, 0xB4, 0xAD, 0xD1, 0x44, 0xEC, 0xBD, 0x7A, 0x79, 0x11, 0xDD, 0xD5,
    0xF5, 0x62, 0xCE, 0x92, 0xAA, 0x3B, 0xF3, 0x50, 0x81, 0xD1, 0xA7, 0xF5, 0xDD, 0x89, 0x95, 0x27,
    0x8C, 0x7E, 0xAC, 0x77, 0x6A, 0x56, 0xF6, 0x15, 0xD9, 0xB7, 0x76, 0x97, 0xE8, 0x21, 0x11, 0x66,
    0xA3, 0x2E, 0xD4, 0xC6, 0x51, 0x3C, 0xEC, 0xC3, 0x04, 0x2D, 0x29, 0x54, 0x9C, 0x6A, 0xBB, 0x17,
    0x9A, 0x6F, 0x91, 0xBE, 0x1E, 0xA0, 0x37, 0x13, 0xDF, 0x0A, 0xB5, 0x96, 0xEB, 0xA6, 0x6D, 0x57,
    0xFA, 0x63, 0x29, 0xF2, 0x44, 0x54, 0xA8, 0xCC, 0x93, 0x68, 0xA4, 0xE9, 0x59, 0x9E, 0x64, 0x49,
    0xA6, 0x50, 0x27, 0x1A, 0xBB, 0x0A, 0xF5, 0xC2, 0x83, 0xC6, 0xFC, 0x28, 0x4F, 0x03, 0x0E, 0x52,
    0x7B, 0x05, 0xE1, 0x90, 0x4A, 0x9C, 0xB1, 0x2A, 0xBD, 0xA8, 0xD3, 0x2D, 0x0C, 0x0A, 0x53, 0xBF,
    0xA4, 0x1F, 0xFC, 0xD6, 0x3F, 0x9B, 0x45, 0xC8, 0xDF, 0x09, 0x64, 0x7B, 0xD4, 0x36, 0x37, 0xD9,
    0xEB, 0xAE, 0xF9, 0xEE, 0x9C, 0x1B, 0xAE, 0xB6, 0xB5, 0xA0, 0x48, 0x3A, 0xB1, 0xCB, 0xC0, 0x85,
    0x45, 0x32, 0x93, 0x6C, 0x36, 0xF4, 0x6D, 0x82, 0x1E, 0x43, 0x6C, 0x44, 0xBE, 0xAE, 0x0F, 0xF6,
    0xEE, 0x0D, 0x8D, 0x6F, 0xD1, 0xAB, 0x91, 0x59, 0xDD, 0x5E, 0xE3, 0x37, 0xEC, 0xE1, 0x15, 0xD3,
    0xDE, 0xC7, 0x28, 0xFA, 0x8D, 0x83, 0x0E, 0xA2, 0xDF, 0xC6, 0x35, 0xC7, 0x9F, 0xAB, 0xE1, 0x4D,
    0xE0, 0x1F, 0x27, 0xFE, 0x2F, 0x8A, 0x37, 0x01, 0xEE, 0x78, 0xB0, 0xB4, 0x45, 0x7F, 0x16, 0x3F,
    0xFA, 0x05, 0x4A, 0x3B, 0x38, 0xEA, 0x78, 0x9C, 0xED, 0x93, 0x3F, 0x12, 0xC1, 0x40, 0x14, 0xC6,
    0x1F, 0x49, 0xFC, 0x6B, 0x98, 0x51, 0xE9, 0x72, 0x84, 0xB0, 0xAD, 0x43, 0x70, 0x00, 0x33, 0x6E,
    0xC0, 0x0D, 0xE2, 0x06, 0xEA, 0x54, 0x8C, 0x4E, 0xC5, 0x0D, 0x62, 0x38, 0x40, 0x8E, 0x90, 0x4A,
    0x4D, 0x63, 0xC6, 0xB0, 0xF2, 0x59, 0x3B, 0x91, 0xC9, 0xEE, 0xA6, 0x40, 0xED, 0xD7, 0xBD, 0x5F,
    0xB3, 0xDF, 0xEC, 0xFB, 0x1E, 0xD1, 0x9B, 0xA1, 0x4D, 0x26, 0x33, 0xC4, 0x8E, 0x21, 0xC7, 0x09,
    0x10, 0x59, 0x9A, 0xF4, 0x38, 0x04, 0x8B, 0x92, 0x22, 0x5B, 0x37, 0x48, 0x7C, 0xC5, 0x5E, 0x91,
    0x32, 0xCA, 0xC9, 0x23, 0x32, 0xFA, 0x99, 0x3C, 0x20, 0x47, 0x27, 0x95, 0x2B, 0x28, 0x54, 0xD3,
    0xA0, 0x2A, 0x32, 0xF6, 0x20, 0xD1, 0x2C, 0x42, 0x11, 0x9B, 0xEB, 0xF2, 0x95, 0x6F, 0x69, 0x4A,
    0xC0, 0x39, 0x17, 0xD9, 0xFA, 0xB6, 0xC8, 0x56, 0x5C, 0xE3, 0x31, 0x60, 0x43, 0xE4, 0x32, 0x03,
    0xF5, 0x8F, 0x14, 0x7A, 0xAC, 0x4D, 0x5D, 0xC6, 0x88, 0x18, 0xB3, 0xE4, 0x20, 0xE1, 0x98, 0xD0,
    0x05, 0x27, 0xF2, 0x80, 0xA6, 0x18, 0xFC, 0xBF, 0xFD, 0xD5, 0x3E, 0x10, 0x05, 0x77, 0x20, 0x58,
    0x8B, 0xAA, 0x06, 0x09, 0xE6, 0x52, 0xEE, 0xF5, 0xB5, 0xD5, 0x84, 0x9C, 0x1A, 0xCB, 0x8C, 0xBF,
    0xEA, 0x8E, 0x5D, 0xD8, 0x9D, 0xC6, 0xEE, 0xE3, 0xEE, 0x84, 0xE2, 0xA6, 0xCC, 0xEE, 0x94, 0xE9,
    0x09, 0x87, 0x4F, 0x01, 0x13, 0x78, 0x9C, 0x63, 0x60, 0x80, 0x81, 0xE4, 0x15, 0xA7, 0xEF, 0xEE,
    0xE9, 0x32, 0x63, 0x64, 0x40, 0x07, 0x2D, 0x7F, 0xFE, 0x43, 0xC0, 0x79, 0x0F, 0x54, 0x09, 0x83,
    0x97, 0xFF, 0x11, 0x60, 0x1E, 0x0B, 0x92, 0x4C, 0xC0, 0x9F, 0xFF, 0xC8, 0xE0, 0x3E, 0x2B, 0x42,
    0xE6, 0xEF, 0x7F, 0x54, 0xF0, 0x1E, 0x26, 0xA7, 0xF0, 0x1B, 0xC2, 0x9F, 0x5D, 0x9E, 0x56, 0xB6,
    0x13, 0xA2, 0xEA, 0x3C, 0x33, 0x44, 0xEA, 0x3B, 0xD8, 0x90, 0x48, 0xA8, 0xD3, 0x5A, 0xC0, 0x92,
    0xFD, 0x60, 0xF6, 0x02, 0x10, 0x73, 0x3E, 0x33, 0xC2, 0x49, 0x3F, 0x40, 0x02, 0x3A, 0x20, 0xE3,
    0x40, 0xAA, 0xE6, 0x23, 0xFB, 0x46, 0x00, 0x2C, 0x07, 0x74, 0xE6, 0x13, 0x20, 0xB5, 0x1E, 0xD5,
    0x9F, 0x02, 0x3F, 0x81, 0x62, 0xF1, 0x0C, 0x01, 0x20, 0x4B, 0x99, 0xD0, 0xFC, 0x0F, 0x76, 0x18,
    0xDB, 0x05, 0x20, 0xC1, 0x89, 0x11, 0x36, 0x0D, 0x40, 0x51, 0xBE, 0x0F, 0xFF, 0xFF, 0xE7, 0x63,
    0xC8, 0x30, 0x30, 0x7C, 0xFD, 0xFF, 0x9F, 0x7F, 0xC2, 0xFF, 0xF7, 0x50, 0xC7, 0x09, 0x94, 0xAE,
    0x3C, 0x33, 0x2B, 0x02, 0x6A, 0x2B, 0xD0, 0x71, 0x5C, 0x0C, 0xDB, 0x25, 0x21, 0x9C, 0x66, 0x48,
    0x60, 0xDD, 0xB7, 0x80, 0x1A, 0xD9, 0x0D, 0x37, 0x61, 0x33, 0x3C, 0x94, 0x7C, 0xD0, 0xCC, 0xDE,
    0x84, 0x14, 0x82, 0x36, 0x28, 0x32, 0x09, 0x28, 0xA1, 0xCB, 0x8E, 0xEC, 0xC7, 0x5F, 0x20, 0x91,
    0xFD, 0x9D, 0x69, 0x33, 0xC0, 0x21, 0xBD, 0x1F, 0x29, 0x04, 0x0E, 0x80, 0x04, 0x3C, 0xC1, 0xCC,
    0x29, 0x20, 0x26, 0x2F, 0x42, 0xEA, 0x0B, 0x90, 0x0B, 0x75, 0x28, 0x43, 0x23, 0x38, 0x90, 0xE0,
    0xE0, 0x33, 0x24, 0xA4, 0x21, 0xE0, 0x20, 0x8A, 0xD4, 0x01, 0x68, 0xFC, 0x40, 0xC0, 0x0F, 0x64,
    0x03, 0x19, 0xDA, 0x98, 0x91, 0x38, 0x0A, 0x15, 0x0C, 0x54, 0x02, 0x85, 0xBB, 0x35, 0x70, 0xC8,
    0x80, 0x62, 0x95, 0x0D, 0xBB, 0x14, 0xD0, 0x0B, 0xFF, 0xED, 0xB1, 0x4B, 0x81, 0x62, 0xE5, 0x3E,
    0x76, 0x29, 0x70, 0xD0, 0x62, 0x66, 0x14, 0x20, 0x10, 0x00, 0x4B, 0x31, 0x63, 0x93, 0x82, 0xE8,
    0xC2, 0x6E, 0x20, 0x28, 0x66, 0xF6, 0x63, 0x97, 0x7A, 0x08, 0x94, 0xD2, 0xC7, 0x2E, 0x65, 0xF0,
    0xF7, 0xFF, 0x7D, 0xEC, 0x56, 0x31, 0x30, 0x38, 0x74, 0xB0, 0x22, 0x73, 0x01, 0x94, 0xB6, 0x12,
    0x83,
]

fa20Glyphs = [
    GFXglyph(width = 53, height = 37, advance_x = 52, left =  0, top = 34, compressed_size = 467, data_offset =    0), # 
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 271, data_offset =  467), # 
    GFXglyph(width = 37, height = 43, advance_x = 36, left =  0, top = 37, compressed_size = 237, data_offset =  738), # 
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 274, data_offset =  975), # 
    GFXglyph(width = 37, height = 43, advance_x = 36, left =  0, top = 37, compressed_size = 245, data_offset = 1249), # 
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 305, data_offset = 1494), # 
    GFXglyph(width = 54, height = 43, advance_x = 52, left = -1, top = 37, compressed_size = 396, data_offset = 1799), # 
    GFXglyph(width = 53, height = 37, advance_x = 52, left =  0, top = 34, compressed_size = 231, data_offset = 2195), # 
    GFXglyph(width = 33, height = 43, advance_x = 36, left =  2, top = 37, compressed_size = 221, data_offset = 2426), # 
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 301, data_offset = 2647), # 
    GFXglyph(width = 42, height = 43, advance_x = 42, left =  0, top = 37, compressed_size = 314, data_offset = 2948), # 
    GFXglyph(width = 32, height = 37, advance_x = 31, left =  0, top = 34, compressed_size = 215, data_offset = 3262), # 
    GFXglyph(width = 49, height = 33, advance_x = 47, left = -1, top = 32, compressed_size = 361, data_offset = 3477), # 
    GFXglyph(width = 47, height = 43, advance_x = 47, left =  0, top = 37, compressed_size = 235, data_offset = 3838), # 
    GFXglyph(width = 53, height = 43, advance_x = 52, left =  0, top = 37, compressed_size = 397, data_offset = 4073), # 
    GFXglyph(width = 43, height = 43, advance_x = 42, left = -1, top = 37, compressed_size = 207, data_offset = 4470), # 
    GFXglyph(width = 54, height = 37, advance_x = 52, left = -1, top = 34, compressed_size = 332, data_offset = 4677), # 
]

fa20Intervals = [
    UnicodeInterval(first = 61958, last = 61958, offset =  0),
    UnicodeInterval(first = 61959, last = 61959, offset =  1),
    UnicodeInterval(first = 62008, last = 62008, offset =  2),
    UnicodeInterval(first = 61882, last = 61882, offset =  3),
    UnicodeInterval(first = 61555, last = 61555, offset =  4),
    UnicodeInterval(first = 61463, last = 61463, offset =  5),
    UnicodeInterval(first = 63172, last = 63172, offset =  6),
    UnicodeInterval(first = 61634, last = 61634, offset =  7),
    UnicodeInterval(first = 61671, last = 61671, offset =  8),
    UnicodeInterval(first = 63278, last = 63278, offset =  9),
    UnicodeInterval(first = 63293, last = 63293, offset = 10),
    UnicodeInterval(first = 61830, last = 61830, offset = 11),
    UnicodeInterval(first = 63347, last = 63347, offset = 12),
    UnicodeInterval(first = 61461, last = 61461, offset = 13),
    UnicodeInterval(first = 62980, last = 62980, offset = 14),
    UnicodeInterval(first = 63087, last = 63087, offset = 15),
    UnicodeInterval(first = 61931, last = 61931, offset = 16),
]

fa20 = GFXfont(
    bitmap = fa20Bitmaps,
    glyph = fa20Glyphs,
    intervals = fa20Intervals,
    interval_count = 17,
    compressed = True,
    advance_y = 42,
    ascender = 37,
    descender = -6,
)