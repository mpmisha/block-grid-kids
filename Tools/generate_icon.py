#!/usr/bin/env python3
"""Generates the Block Grid Kids app icon.

The icon is original artwork drawn from scratch: a blue gradient backdrop with
a small grid of beveled candy blocks, matching the in-game block style.

Usage:
    python3 Tools/generate_icon.py

Writes: BlockGridKids/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""

from __future__ import annotations

import colorsys
import os

from PIL import Image, ImageDraw

SIZE = 1024
OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "BlockGridKids",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "AppIcon-1024.png",
)

BACKGROUND_TOP = (92, 120, 219)
BACKGROUND_BOTTOM = (56, 66, 153)

PURPLE = (153, 102, 237)
GREEN = (82, 201, 102)
ORANGE = (250, 153, 51)
YELLOW = (252, 212, 64)
PINK = (247, 102, 166)
CYAN = (64, 209, 209)

# 4x4 icon grid. None means an empty slot.
LAYOUT = [
    [PURPLE, PURPLE, None, GREEN],
    [PURPLE, PURPLE, None, GREEN],
    [ORANGE, None, CYAN, CYAN],
    [ORANGE, YELLOW, PINK, None],
]


def scale_rgb(rgb, factor):
    """Scales brightness in HSV space, like the in-game bevel shading."""
    r, g, b = (channel / 255.0 for channel in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    v = max(0.0, min(1.0, v * factor))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def blend_white(rgb, amount):
    """Blends a color toward white. PIL's RGBA draw blending is unreliable on a
    transparent layer, so translucent-looking highlights are pre-blended here."""
    return tuple(int(channel + (255 - channel) * amount) for channel in rgb)


def draw_gradient(image):
    draw = ImageDraw.Draw(image)
    for y in range(SIZE):
        ratio = y / (SIZE - 1)
        color = tuple(
            int(BACKGROUND_TOP[i] + (BACKGROUND_BOTTOM[i] - BACKGROUND_TOP[i]) * ratio)
            for i in range(3)
        )
        draw.line([(0, y), (SIZE, y)], fill=color)


def draw_block(overlay, x, y, side, color):
    """Draws one beveled block: dark body, raised face, gloss and highlight."""
    draw = ImageDraw.Draw(overlay)
    radius = side * 0.22

    body = [x, y, x + side, y + side]
    draw.rounded_rectangle(body, radius=radius, fill=scale_rgb(color, 0.62) + (255,))

    inset = side * 0.08
    face = [
        x + inset,
        y + inset * 0.7,
        x + side - inset,
        y + side - inset * 1.8,
    ]
    draw.rounded_rectangle(face, radius=radius * 0.8, fill=color + (255,))

    gloss_bottom = face[1] + (face[3] - face[1]) * 0.38
    draw.rounded_rectangle(
        [face[0], face[1], face[2], gloss_bottom],
        radius=radius * 0.7,
        fill=blend_white(color, 0.22) + (255,),
    )

    highlight_w = side * 0.19
    highlight_h = side * 0.10
    hx = face[0] + side * 0.09
    hy = face[1] + side * 0.07
    draw.rounded_rectangle(
        [hx, hy, hx + highlight_w, hy + highlight_h],
        radius=highlight_h / 2,
        fill=blend_white(color, 0.62) + (255,),
    )


def draw_empty_cell(overlay, x, y, side):
    draw = ImageDraw.Draw(overlay)
    inset = side * 0.06
    draw.rounded_rectangle(
        [x + inset, y + inset, x + side - inset, y + side - inset],
        radius=side * 0.22,
        fill=(46, 52, 96, 255),
        outline=(86, 96, 150, 255),
        width=max(2, int(side * 0.018)),
    )


def main():
    image = Image.new("RGB", (SIZE, SIZE), BACKGROUND_TOP)
    draw_gradient(image)

    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    columns = len(LAYOUT[0])
    rows = len(LAYOUT)
    grid_side = SIZE * 0.70
    cell = grid_side / columns
    origin_x = (SIZE - grid_side) / 2
    origin_y = (SIZE - cell * rows) / 2

    # Soft plate behind the grid so the blocks read clearly at small sizes.
    plate = ImageDraw.Draw(overlay)
    pad = cell * 0.22
    plate.rounded_rectangle(
        [
            origin_x - pad,
            origin_y - pad,
            origin_x + grid_side + pad,
            origin_y + cell * rows + pad,
        ],
        radius=cell * 0.5,
        fill=(38, 45, 96, 255),
    )

    for row_index, row in enumerate(LAYOUT):
        for col_index, color in enumerate(row):
            x = origin_x + col_index * cell
            y = origin_y + row_index * cell
            if color is None:
                draw_empty_cell(overlay, x, y, cell)
            else:
                draw_block(overlay, x, y, cell, color)

    image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, "PNG")
    print(f"Wrote {OUTPUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
