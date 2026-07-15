"""Generate the BillKraft app icon — letter 'B' stylized as an invoice.

Concept:
  - White rounded square background.
  - Blue (#2563EB) letter 'B' with an invoice-document feel:
    the two bumps of the 'B' suggest stacked line items.
  - Flat design, rounded corners, scalable.

Outputs (1024x1024):
  - icon.png            — full-bleed, white bg + blue 'B'
  - icon_foreground.png — transparent bg, content in central 66% safe zone
  - preview.png         — 512x512 composite on light card

NOTE: This is a PLACEHOLDER brand logo generated programmatically.
Replace with a designer-crafted version before production launch.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = '/home/z/my-project/download/quickbill/assets/icon'
os.makedirs(OUT_DIR, exist_ok=True)

BLUE = (37, 99, 235, 255)          # #2563EB
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


def _draw_b_mark(draw, cx, cy, scale):
    """Draws a bold 'B' centered at (cx, cy) in blue."""
    s = scale
    font = _find_font(int(580 * s))
    text = 'B'
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = cx - tw // 2 - bbox[0]
    ty = cy - th // 2 - bbox[1] - int(20 * s)
    draw.text((tx, ty), text, fill=BLUE, font=font)

    # Draw 2 short horizontal lines below the 'B' to suggest invoice line items.
    line_color = BLUE
    line_w = int(280 * s)
    line_h = int(12 * s)
    line_x = cx - line_w // 2
    for i, offset in enumerate([-60, -20]):
        ly = cy + int(offset * s) + int(180 * s)
        draw.rounded_rectangle(
            [line_x, ly, line_x + line_w, ly + line_h],
            radius=int(4 * s), fill=line_color,
        )


def make_full_bleed():
    img = Image.new('RGBA', (SIZE, SIZE), WHITE)
    draw = ImageDraw.Draw(img, 'RGBA')
    _draw_b_mark(draw, SIZE // 2, SIZE // 2, 1.0)
    path = os.path.join(OUT_DIR, 'icon.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_foreground():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')
    _draw_b_mark(draw, SIZE // 2, SIZE // 2, 0.66)
    path = os.path.join(OUT_DIR, 'icon_foreground.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_preview():
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
