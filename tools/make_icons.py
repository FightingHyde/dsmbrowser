#!/usr/bin/env python3
import zlib, struct, sys, os

def write_png(path, size, fg=(66,133,244,255), bg=(0,0,0,0)):
    cx = cy = size / 2.0
    r = size * 0.42
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            dx, dy = x + .5 - cx, y + .5 - cy
            rows += bytes(fg if dx*dx + dy*dy <= r*r else bg)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    hdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    blob = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", hdr)
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
    open(path, "wb").write(blob)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for s in (16, 24, 32, 48, 64, 72, 128, 256):
    write_png(os.path.join(out, f"icon_{s}.png"), s)
if len(sys.argv) > 2:
    write_png(os.path.join(sys.argv[2], "PACKAGE_ICON.PNG"), 72)
    write_png(os.path.join(sys.argv[2], "PACKAGE_ICON_256.PNG"), 256)
print("icons written to", out)
