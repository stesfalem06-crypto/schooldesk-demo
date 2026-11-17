#!/usr/bin/env python3
"""Fail when a screenshot is almost a single colour."""
import struct
import sys


def pixels(path):
    data = open(path, "rb").read()
    if data[:2] != b"BM":
        raise SystemExit(f"{path} is not a bitmap")
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bits = struct.unpack_from("<H", data, 28)[0]
    if bits not in (24, 32):
        raise SystemExit(f"unsupported bitmap depth {bits}")
    step = bits // 8
    stride = (width * step + 3) & ~3
    flip = height > 0
    height = abs(height)
    samples = []
    yellow = 0
    for y in range(height):
        row = (height - 1 - y) if flip else y
        start = offset + row * stride
        for x in range(width):
            i = start + x * step
            b, g, r = data[i], data[i + 1], data[i + 2]
            if r > 220 and g > 200 and b < 80 and r - b > 140:
                yellow += 1
            if y % 8 == 0 and x % 8 == 0:
                samples.append((r, g, b))
    return samples, yellow


def main():
    path = sys.argv[1]
    sample, yellow = pixels(path)
    if len(sample) < 20:
        raise SystemExit("screenshot is too small")
    mean = tuple(sum(p[i] for p in sample) / len(sample) for i in range(3))
    var = sum(sum((p[i] - mean[i]) ** 2 for i in range(3)) for p in sample) / len(sample)
    print(f"pixels={len(sample)} mean={tuple(round(v, 1) for v in mean)} variance={var:.1f} yellow={yellow}")
    if var < 80:
        raise SystemExit("screenshot is mostly one colour")
    if yellow > 40:
        raise SystemExit(f"yellow debug underlines on {path}")


if __name__ == "__main__":
    main()
