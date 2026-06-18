import os
from collections import deque

from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = r"C:\Users\Lean\Downloads\ChatGPT Image 17 jun 2026, 11_34_07 p.m..png"
OUTPUT_DIR = os.path.join(REPO_ROOT, 'autocajon', 'icons')


def is_background(r, g, b, a, tolerance=28):
    if a < 10:
        return True
    brightness = (r + g + b) / 3.0
    spread = max(r, g, b) - min(r, g, b)
    return brightness >= 175 and spread <= tolerance


def remove_background(img):
    img = img.convert('RGBA')
    pixels = img.load()
    width, height = img.size
    visited = set()
    queue = deque([
        (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)
    ])

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        visited.add((x, y))
        r, g, b, a = pixels[x, y]
        if not is_background(r, g, b, a):
            continue
        pixels[x, y] = (r, g, b, 0)
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    return img


def fit_square(img, size):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    fitted = img.copy()
    fitted.thumbnail((size, size), Image.LANCZOS)
    offset_x = (size - fitted.width) // 2
    offset_y = (size - fitted.height) // 2
    canvas.paste(fitted, (offset_x, offset_y), fitted)
    return canvas


def generate_icons():
    if not os.path.exists(SOURCE):
        raise SystemExit(f'No existe la imagen fuente: {SOURCE}')

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    base = remove_background(Image.open(SOURCE))
    bbox = base.getbbox()
    if bbox:
        base = base.crop(bbox)

    outputs = [
        ('autocajon_24.png', 24),
        ('autocajon_32.png', 32),
    ]

    for filename, size in outputs:
        out_path = os.path.join(OUTPUT_DIR, filename)
        fit_square(base, size).save(out_path, 'PNG')
        print(f'Generado: {out_path} ({size}x{size})')


if __name__ == '__main__':
    generate_icons()
