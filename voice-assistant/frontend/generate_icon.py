#!/usr/bin/env python3
"""Generate a simple purple mic icon for the PWA."""
try:
    from PIL import Image, ImageDraw, ImageFont
    import math

    def generate_icon(size=512, output_path="icon.png"):
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Background circle
        padding = size * 0.05
        draw.ellipse(
            [padding, padding, size - padding, size - padding],
            fill="#6c63ff"
        )

        # Mic body (rounded rectangle)
        cx = size / 2
        mic_w = size * 0.22
        mic_h = size * 0.38
        mic_x0 = cx - mic_w / 2
        mic_y0 = size * 0.18
        mic_x1 = cx + mic_w / 2
        mic_y1 = mic_y0 + mic_h
        r = mic_w * 0.5
        draw.rounded_rectangle([mic_x0, mic_y0, mic_x1, mic_y1], radius=r, fill="white")

        # Stand arc
        arc_r = size * 0.22
        arc_cx = cx
        arc_cy = mic_y1 - size * 0.04
        draw.arc(
            [arc_cx - arc_r, arc_cy - arc_r, arc_cx + arc_r, arc_cy + arc_r],
            start=0, end=180,
            fill="white",
            width=int(size * 0.04)
        )

        # Stand line
        stand_x = cx
        stand_y_top = arc_cy
        stand_y_bot = stand_y_top + arc_r * 0.55
        line_w = int(size * 0.04)
        draw.line([stand_x, stand_y_top, stand_x, stand_y_bot], fill="white", width=line_w)

        # Base line
        base_w = size * 0.28
        draw.line(
            [stand_x - base_w / 2, stand_y_bot, stand_x + base_w / 2, stand_y_bot],
            fill="white", width=line_w
        )

        img.save(output_path)
        print(f"Icon saved to {output_path}")

    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    generate_icon(512, os.path.join(script_dir, "icon.png"))

except ImportError:
    print("Pillow not installed. Run: pip install Pillow")
    print("Alternatively, place any 512x512 PNG as icon.png in this directory.")
