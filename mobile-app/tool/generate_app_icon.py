#!/usr/bin/env python3
"""Generate the CosmicGuide launcher icon from the app theme.

Pure stdlib (no Pillow): renders a gold astroid "sparkle" on the app's navy
gradient and writes the PNGs that flutter_launcher_icons / flutter_native_splash
consume. Re-run after changing the theme colours:

    python3 tool/generate_app_icon.py
"""

from __future__ import annotations

import math
import os
import struct
import zlib

SIZE = 1024
SS = 2  # supersampling factor for anti-aliasing

# AppColors: primary -> surface, accent gold.
TOP = (0x1A, 0x1A, 0x2E)
BOTTOM = (0x0F, 0x34, 0x60)
GOLD = (0xFF, 0xD7, 0x00)
GOLD_DIM = (0xFF, 0xA0, 0x00)

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "images")


def _write_png(path: str, width: int, height: int, rows: list[bytes], alpha: bool) -> None:
    raw = b"".join(b"\x00" + row for row in rows)
    color_type = 6 if alpha else 2

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as fh:
        fh.write(png)


def _sparkle_coverage(x: float, y: float, cx: float, cy: float, r: float) -> bool:
    """Astroid star: sqrt(|dx|/r) + sqrt(|dy|/r) <= 1 gives a 4-point sparkle."""
    dx = abs(x - cx) / r
    dy = abs(y - cy) / r
    if dx > 1 or dy > 1:
        return False
    return math.sqrt(dx) + math.sqrt(dy) <= 1.0


def _render(size: int, with_background: bool, scale: float) -> list[bytes]:
    n = size * SS
    cx = cy = n / 2.0
    main_r = n * scale

    # A couple of small companion sparkles for depth.
    companions = [
        (cx + main_r * 0.95, cy - main_r * 0.80, main_r * 0.26),
        (cx - main_r * 0.88, cy + main_r * 0.92, main_r * 0.17),
    ]

    rows: list[bytes] = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            acc_r = acc_g = acc_b = acc_a = 0
            for sy in range(SS):
                yy = py * SS + sy
                for sx in range(SS):
                    xx = px * SS + sx

                    hit_main = _sparkle_coverage(xx, yy, cx, cy, main_r)
                    hit_small = any(
                        _sparkle_coverage(xx, yy, ccx, ccy, cr)
                        for ccx, ccy, cr in companions
                    )

                    if hit_main or hit_small:
                        # Vertical gold fade so the mark is not flat.
                        t = yy / n
                        col = tuple(
                            int(GOLD[i] + (GOLD_DIM[i] - GOLD[i]) * t) for i in range(3)
                        )
                        a = 255
                    elif with_background:
                        t = yy / n
                        col = tuple(
                            int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)
                        )
                        a = 255
                    else:
                        col = (0, 0, 0)
                        a = 0

                    acc_r += col[0] * a // 255
                    acc_g += col[1] * a // 255
                    acc_b += col[2] * a // 255
                    acc_a += a

            samples = SS * SS
            a = acc_a // samples
            if a == 0:
                row += b"\x00\x00\x00\x00" if not with_background else b"\x00\x00\x00"
                continue
            # Un-premultiply so edges stay gold instead of darkening.
            r = min(255, acc_r * 255 // max(1, acc_a))
            g = min(255, acc_g * 255 // max(1, acc_a))
            b = min(255, acc_b * 255 // max(1, acc_a))
            row += bytes((r, g, b, a)) if not with_background else bytes((r, g, b))
        rows.append(bytes(row))
    return rows


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    icon = os.path.join(OUT_DIR, "app_icon.png")
    _write_png(icon, SIZE, SIZE, _render(SIZE, True, 0.30), alpha=False)
    print(f"wrote {icon}")

    # Adaptive foreground: inset so Android's mask cannot clip the sparkle.
    fg = os.path.join(OUT_DIR, "app_icon_foreground.png")
    _write_png(fg, SIZE, SIZE, _render(SIZE, False, 0.21), alpha=True)
    print(f"wrote {fg}")

    splash = os.path.join(OUT_DIR, "splash_logo.png")
    _write_png(splash, SIZE, SIZE, _render(SIZE, False, 0.26), alpha=True)
    print(f"wrote {splash}")


if __name__ == "__main__":
    main()
