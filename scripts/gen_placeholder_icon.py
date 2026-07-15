"""Generate placeholder app icons for QuickBill.

Produces two PNGs:
  - assets/icon/icon.png            (1024x1024, full-bleed)
  - assets/icon/icon_foreground.png (1024x1024, content within central 66%
                                     per Android adaptive icon safe zone)

Both are a saffron "Q" monogram on white - a PLACEHOLDER pending a real
designed icon. Run once; do NOT regenerate on every build.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUTPUT_DIR = '/home/z/my-project/download/quickbill/assets/icon'
os.makedirs(OUTPUT_DIR, exist_ok=True)

SAFFRON = (239, 138, 23, 255)   # #EF8A17
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


def make_full_bleed():
    img = Image.new('RGBA', (SIZE, SIZE), WHITE)
    draw = ImageDraw.Draw(img)
    margin = int(SIZE * 0.075)
    box = [margin, margin, SIZE - margin, SIZE - margin]
    radius = int(SIZE * 0.18)
    draw.rounded_rectangle(box, radius=radius, fill=SAFFRON)
    font = _find_font(int(SIZE * 0.62))
    text = 'Q'
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1] - int(SIZE * 0.02)
    draw.text((tx, ty), text, fill=WHITE, font=font)
    path = os.path.join(OUTPUT_DIR, 'icon.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


def make_foreground():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font = _find_font(int(SIZE * 0.50))
    text = 'Q'
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1] - int(SIZE * 0.02)
    draw.text((tx, ty), text, fill=SAFFRON, font=font)
    path = os.path.join(OUTPUT_DIR, 'icon_foreground.png')
    img.save(path, 'PNG')
    print(f'Wrote {path} ({os.path.getsize(path)} bytes)')


if __name__ == '__main__':
    make_full_bleed()
    make_foreground()
