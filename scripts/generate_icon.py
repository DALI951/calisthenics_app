#!/usr/bin/env python3
"""Generate the Calisthenics app icon (1024x1024 PNG) and adaptive foreground.

Design: dark rounded square (#0A0A0F), three ascending red bars (#DC2626)
like a pull-up bar / progress glyph. No text, no gradients, no clutter.
Regenerate anytime with: python scripts/generate_icon.py
Outputs: assets/icon/icon.png (legacy full icon)
         assets/icon/icon_foreground.png (adaptive foreground, safe zone)
"""
import io
import math
import os
from PIL import Image, ImageDraw

SIZE = 1024
BG = (10, 10, 15, 255)          # #0A0A0F
RED = (220, 38, 38, 255)        # #DC2626
RED_DARK = (185, 28, 28, 255)   # #B91C1C
FG_RED = (230, 60, 60, 255)     # slightly brighter red for adaptive fg


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def make_icon(red, glow=True):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(SIZE * 0.22)
    rounded_rect(d, (0, 0, SIZE, SIZE), r, BG)
    # subtle red glow behind bars
    if glow:
        glow_im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_im)
        gd.ellipse((SIZE * 0.18, SIZE * 0.34, SIZE * 0.82, SIZE * 0.92),
                   fill=(239, 68, 68, 38))
        glow_im = glow_im.filter(
            __import__("PIL.ImageFilter", fromlist=["ImageFilter"]).GaussianBlur(60)
        )
        img.alpha_composite(glow_im)
        d = ImageDraw.Draw(img)
    # bars: x margins, baseline, three bars of increasing height
    margin = SIZE * 0.22
    gap = SIZE * 0.055
    bar_w = (SIZE - 2 * margin - 2 * gap) / 3
    baseline_top = SIZE * 0.88
    heights = [0.30, 0.50, 0.70]
    for i, h in enumerate(heights):
        x0 = margin + i * (bar_w + gap)
        x1 = x0 + bar_w
        y1 = baseline_top
        y0 = SIZE - (SIZE - baseline_top) - (SIZE * h)
        # actual bar: y0 = baseline_top - height_in_px
        top = baseline_top - (SIZE * 0.62) * h
        rounded_rect(d, (x0, top, x1, y1), bar_w * 0.22, red if (i != 2 or not glow) else RED)
    return img


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)
    icon = make_icon(RED, glow=False)
    icon.save(os.path.join(out_dir, "icon.png"))
    fg = make_icon(FG_RED, glow=True)
    fg.save(os.path.join(out_dir, "icon_foreground.png"))
    print("icon.png + icon_foreground.png written to", os.path.normpath(out_dir))


if __name__ == "__main__":
    main()