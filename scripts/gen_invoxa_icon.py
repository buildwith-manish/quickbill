"""Generate the Invoxa app icon — a stacked-invoice + checkmark mark.

Concept:
  - Deep indigo rounded square background (#4F46E5) — premium, global,
    no cultural association.
  - White negative-space stack of 3 invoice rectangles (decreasing width,
    slightly offset) — universally readable as "documents/invoices".
  - Mint green checkmark (#10B981) overlay on the top invoice — signals
    "verified/paid/done", the trust cue that matters for a billing app.

Outputs two PNGs (1024x1024):
  - icon.png            — full-bleed, for iOS + Play Store
  - icon_foreground.png — content in central 66% per Android adaptive icon
                          safe zone, transparent background
"""
from PIL import Image, ImageDraw
import os
import math

OUT_DIR = '/home/z/my-project/download/invoxa-icons'
os.makedirs(OUT_DIR, exist_ok=True)

# Brand palette
INDIGO = (79, 70, 229, 255)        # #4F46E5
INDIGO_DARK = (67, 56, 202, 255)   # gradient bottom
WHITE = (255, 255, 255, 255)
MINT = (16, 185, 129, 255)         # #10B981
MINT_DARK = (5, 150, 105, 255)     # checkmark shadow

SIZE = 1024


def _rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def _gradient_background(size):
    """Vertical indigo gradient — top lighter, bottom darker. Premium feel."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    top = INDIGO
    bot = INDIGO_DARK
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(size):
            img.putpixel((x, y), (r, g, b, 255))
    return img


def _draw_invoice_stack(draw, cx, cy, scale):
    """Draws 3 stacked invoice rectangles centered at (cx, cy).
    Each lower rectangle is slightly offset and narrower — the classic
    'stacked papers' look."""
    w = int(440 * scale)
    h = int(540 * scale)
    offset = int(28 * scale)
    radius = int(24 * scale)

    # Bottom invoice (darkest white — slight transparency for depth)
    _rounded_rect(
        draw,
        [cx - w // 2 + offset, cy - h // 2 + offset,
         cx + w // 2 + offset, cy + h // 2 + offset],
        radius,
        (255, 255, 255, 230),
    )
    # Middle invoice
    _rounded_rect(
        draw,
        [cx - w // 2 + offset // 2, cy - h // 2 + offset // 2,
         cx + w // 2 + offset // 2, cy + h // 2 + offset // 2],
        radius,
        (255, 255, 255, 245),
    )
    # Top invoice (solid white — the checkmark sits on this one)
    _rounded_rect(
        draw,
        [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2],
        radius,
        WHITE,
    )

    # Draw 3 horizontal "text lines" on the top invoice to suggest a real
    # document (not just a blank rectangle). Subtle gray lines.
    line_color = (203, 213, 225, 255)  # slate-300
    line_h = int(8 * scale)
    line_w_short = int(w * 0.55)
    line_w_long = int(w * 0.75)
    line_x_start = cx - w // 2 + int(40 * scale)
    line_y_start = cy - h // 2 + int(90 * scale)
    line_gap = int(48 * scale)
    for i in range(3):
        lw = line_w_short if i % 2 == 0 else line_w_long
        _rounded_rect(
            draw,
            [line_x_start, line_y_start + i * line_gap,
             line_x_start + lw, line_y_start + i * line_gap + line_h],
            int(4 * scale),
            line_color,
        )


def _draw_checkmark(draw, cx, cy, scale):
    """Bold mint-green checkmark, centered on the top invoice.
    Drawn as a filled polygon for a solid, confident stroke."""
    s = scale
    # Checkmark vertices — a thick tick. Bottom-left of tick at (cx-90, cy),
    # corner at (cx-20, cy+70), top-right at (cx+100, cy-90).
    pts_outer = [
        (cx - int(100 * s), cy + int(10 * s)),    # bottom-left start
        (cx - int(20 * s), cy + int(90 * s)),     # bottom corner
        (cx + int(120 * s), cy - int(110 * s)),   # top-right tip
        (cx + int(80 * s), cy - int(140 * s)),    # top-right outer
        (cx - int(20 * s), cy + int(40 * s)),     # bottom corner inner
        (cx - int(70 * s), cy - int(20 * s)),     # bottom-left inner
    ]
    draw.polygon(pts_outer, fill=MINT)

    # Subtle inner shadow on the checkmark for depth (a thinner darker
    # polygon offset down-right by a few pixels).
    shadow_offset = int(4 * s)
    pts_shadow = [(x + shadow_offset, y + shadow_offset) for x, y in pts_outer]
    # We don't actually fill the shadow — just hint at it by drawing a
    # darker outline on the bottom-right edge. Keep it subtle.
    draw.line(
        [pts_outer[2], pts_outer[3], pts_outer[4]],
        fill=MINT_DARK,
        width=int(6 * s),
    )


def make_full_bleed():
    """1024x1024 icon with gradient indigo background + invoice stack +
    checkmark. For iOS App Icon and Play Store listing."""
    img = _gradient_background(SIZE)
    draw = ImageDraw.Draw(img, 'RGBA')

    # The icon fills the whole canvas — content is centered with a small
    # margin so the rounded square reads as a tile.
    _draw_invoice_stack(draw, SIZE // 2, SIZE // 2 + 20, 1.0)
    _draw_checkmark(draw, SIZE // 2, SIZE // 2 + 20, 1.0)

    path = os.path.join(OUT_DIR, 'icon.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_foreground():
    """1024x1024 foreground with transparent background. Content sits in
    the central 66% per Android adaptive icon safe zone. The OS applies
    the background color (#4F46E5 from pubspec) behind it."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')

    # Scale down to 66% so content stays within the safe zone. Center it.
    scale = 0.66
    _draw_invoice_stack(draw, SIZE // 2, SIZE // 2, scale)
    _draw_checkmark(draw, SIZE // 2, SIZE // 2, scale)

    path = os.path.join(OUT_DIR, 'icon_foreground.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_preview():
    """A 512x512 preview composite showing the full icon on a white card
    — useful for quickly eyeballing the result."""
    full = Image.open(os.path.join(OUT_DIR, 'icon.png')).convert('RGBA')
    preview = Image.new('RGBA', (512, 512), (248, 250, 252, 255))
    preview.alpha_composite(full.resize((512, 512)))
    path = os.path.join(OUT_DIR, 'preview.png')
    preview.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


if __name__ == '__main__':
    make_full_bleed()
    make_foreground()
    make_preview()
