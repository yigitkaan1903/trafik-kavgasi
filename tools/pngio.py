"""Küçük PNG okuyucu (Pillow gerekmez): RGBA piksel listesi döndürür. PixelLab çıktılarını haritaya basmak için."""
import zlib, struct, sys
def read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8; idat = b''; w = h = 0; ctype = 6; plte = None; trns = None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos+4])[0]; tag = data[pos+4:pos+8]; body = data[pos+8:pos+8+ln]; pos += 12 + ln
        if tag == b'IHDR': w, h, bd, ctype = struct.unpack('>IIBB', body[:10])
        elif tag == b'PLTE': plte = [tuple(body[i:i+3]) for i in range(0, len(body), 3)]
        elif tag == b'tRNS': trns = body
        elif tag == b'IDAT': idat += body
    raw = zlib.decompress(idat)
    bpp = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ctype]
    stride = w * bpp; rows = []; prev = bytearray(stride); i = 0
    for y in range(h):
        f = raw[i]; line = bytearray(raw[i+1:i+1+stride]); i += 1 + stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c; pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line); prev = line
    px = []
    for line in rows:
        row = []
        for x in range(w):
            if ctype == 6: row.append(tuple(line[x*4:x*4+4]))
            elif ctype == 2: row.append((*line[x*3:x*3+3], 255))
            elif ctype == 3:
                k = line[x]; row.append((*plte[k], trns[k] if trns and k < len(trns) else 255))
            elif ctype == 4: row.append((line[x*2], line[x*2], line[x*2], line[x*2+1]))
            else: row.append((line[x], line[x], line[x], 255))
        px.append(row)
    return px
