"""Generate BlackwellUI's own round UI textures.

Usage: python -I gen_textures.py <addon_dir>

Writes media/textures/round.tga: a 64x64 white disc with an anti-aliased
edge (16x supersampling). Rounded panels use its quarters as corners,
bars use its halves as end caps, dots and rings use it whole.
Format matches the addon's other textures: uncompressed true-colour TGA
(type 2), 32 bit BGRA, image descriptor 0x28 (top-left origin, 8 alpha bits).
Also prints the dot positions for B:DotRing (unit circle, clockwise from
the top), so the addon needs no trigonometry at runtime.
"""
import math
import os
import struct
import sys

SIZE = 64
SAMPLES = 4  # 4x4 = 16 samples per pixel


def disc():
    radius = SIZE / 2.0
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            inside = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    px = x + (sx + 0.5) / SAMPLES - radius
                    py = y + (sy + 0.5) / SAMPLES - radius
                    if px * px + py * py <= radius * radius:
                        inside += 1
            alpha = round(255 * inside / (SAMPLES * SAMPLES))
            pixels += bytes((255, 255, 255, alpha))
    return bytes(pixels)


def write_tga(path, width, height, bgra):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(bgra)


def main():
    root = sys.argv[1]
    out = os.path.join(root, "media", "textures", "round.tga")
    write_tga(out, SIZE, SIZE, disc())
    print("wrote", out, os.path.getsize(out), "bytes")
    count = 24
    points = []
    for i in range(count):
        a = 2 * math.pi * i / count
        points.append("{ %.4f, %.4f }" % (math.sin(a), math.cos(a)))
    print("RING_%d = { %s }" % (count, ", ".join(points)))


if __name__ == "__main__":
    main()
