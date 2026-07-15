"""Generate the Invory app icon — letter 'I' + minimal invoice shape.

Concept:
  - White rounded square background (per spec).
  - Blue (#2563EB) letter 'I' stylized as an invoice/document:
    the 'I' has a top bar (invoice header), a vertical stem, and a
    bottom bar (invoice footer) — doubling as both a letter and a document.
  - Flat design, rounded corners, scalable.

Outputs (1024x1024):
  - icon.png            — full-bleed, white bg + blue 'I'-invoice
  - icon_foreground.png — transparent bg, content in central 66% safe zone
                          for Android adaptive icon
  - preview.png         — 512x512 composite on light card for eyeballing

NOTE: This is a PLACEHOLDER brand logo generated programmatically.
Replace with a designer-crafted version before production launch.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = '/home/z/my-project/download/invory-icons'
os.makedirs(OUT_DIR, exist_ok=True)

# Brand palette per rebrand spec
BLUE = (37, 99, 235, 255)          # #2563EB primary
BLUE_DARK = (29, 78, 216, 255)     # subtle depth
WHITE = (255, 255, 255, 255)
SIZE = 1024


def _find_font(size):
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _draw_i_invoice(draw, cx, cy, scale):
    """Draws the letter 'I' stylized as an invoice document.
    Top bar = invoice header, stem = document body, bottom bar = footer.
    All in blue (#2563EB), rounded corners."""
    s = scale
    # Dimensions
    bar_w = int(380 * s)
    bar_h = int(70 * s)
    stem_w = int(90 * s)
    stem_h = int(380 * s)
    radius = int(16 * s)

    # Top bar (invoice header)
    top_y = cy - int(220 * s)
    draw.rounded_rectangle(
        [cx - bar_w // 2, top_y, cx + bar_w // 2, top_y + bar_h],
        radius=radius, fill=BLUE,
    )
    # Bottom bar (invoice footer)
    bot_y = cy + int(150 * s)
    draw.rounded_rectangle(
        [cx - bar_w // 2, bot_y, cx + bar_w // 2, bot_y + bar_h],
        radius=radius, fill=BLUE,
    )
    # Stem (document body) — connects top and bottom bars
    stem_top = top_y + bar_h
    stem_bot = bot_y
    draw.rounded_rectangle(
        [cx - stem_w // 2, stem_top, cx + stem_w // 2, stem_bot],
        radius=radius, fill=BLUE,
    )

    # Subtle document lines on the stem (3 short horizontal lines suggesting
    # invoice line items). Carved out as white.
    line_color = WHITE
    line_w = int(stem_w * 0.6)
    line_h = int(10 * s)
    line_x = cx - line_w // 2
    for i, offset in enumerate([-90, -30, 30]):
        ly = cy + int(offset * s)
        draw.rounded_rectangle(
            [line_x, ly, line_x + line_w, ly + line_h],
            radius=int(4 * s), fill=line_color,
        )


def make_full_bleed():
    """1024x1024 white background + blue 'I'-invoice mark."""
    img = Image.new('RGBA', (SIZE, SIZE), WHITE)
    draw = ImageDraw.Draw(img, 'RGBA')
    _draw_i_invoice(draw, SIZE // 2, SIZE // 2, 1.0)
    path = os.path.join(OUT_DIR, 'icon.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_foreground():
    """1024x1024 transparent bg, content in central 66% safe zone."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')
    _draw_i_invoice(draw, SIZE // 2, SIZE // 2, 0.66)
    path = os.path.join(OUT_DIR, 'icon_foreground.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_preview():
    """512x512 preview on light card."""
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
