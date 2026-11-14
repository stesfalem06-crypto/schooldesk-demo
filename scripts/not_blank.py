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
    for y in range(0, height, 8):
        row = (height - 1 - y) if flip else y
        start = offset + row * stride
        for x in range(0, width, 8):
            i = start + x * step
            b, g, r = data[i], data[i + 1], data[i + 2]
            samples.append((r, g, b))
    return samples


def main():
    path = sys.argv[1]
    sample = pixels(path)
    if len(sample) < 20:
        raise SystemExit("screenshot is too small")
    mean = tuple(sum(p[i] for p in sample) / len(sample) for i in range(3))
    var = sum(sum((p[i] - mean[i]) ** 2 for i in range(3)) for p in sample) / len(sample)
    print(f"pixels={len(sample)} mean={tuple(round(v, 1) for v in mean)} variance={var:.1f}")
    if var < 80:
        raise SystemExit("screenshot is mostly one colour")


if __name__ == "__main__":
    main()
