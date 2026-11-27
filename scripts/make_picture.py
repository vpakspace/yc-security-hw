#!/usr/bin/env python3
"""Генерирует картинку для бакета: terraform/files/picture.png.

Картинка нарисована самим скриптом (градиент + схема «клиент → балансировщик → три ВМ»),
поэтому в репозитории нет файла с чужой лицензией. Запуск:  python3 scripts/make_picture.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1200, 630
OUT = Path(__file__).resolve().parent.parent / "terraform" / "files" / "picture.png"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def gradient() -> Image.Image:
    """Вертикальный градиент от тёмно-синего к бирюзовому."""
    img = Image.new("RGB", (W, H))
    top, bottom = (16, 36, 84), (14, 116, 144)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    return img


def box(d: ImageDraw.ImageDraw, xy, text: str, fill, font) -> None:
    d.rounded_rectangle(xy, radius=14, fill=fill, outline=(255, 255, 255), width=3)
    x0, y0, x1, y1 = xy
    w = d.textlength(text, font=font)
    d.text(((x0 + x1 - w) / 2, (y0 + y1) / 2 - 14), text, font=font, fill=(255, 255, 255))


def main() -> None:
    img = gradient()
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(FONT_BOLD, 54)
    sub = ImageFont.truetype(FONT, 28)
    label = ImageFont.truetype(FONT_BOLD, 28)

    d.text((70, 50), "Балансировщик нагрузки", font=title, fill=(255, 255, 255))
    d.text((70, 125), "Yandex Cloud · Instance Group · Object Storage", font=sub, fill=(205, 235, 245))

    # клиент → балансировщик (NLB или ALB) → три ВМ
    box(d, (70, 300, 270, 380), "клиент", (60, 90, 150), label)
    box(d, (350, 300, 690, 380), "балансировщик", (200, 110, 30), label)
    for i, y in enumerate((190, 300, 410), start=1):
        box(d, (820, y, 1090, y + 80), f"lamp-{i}", (20, 130, 90), label)
        d.line([(690, 340), (820, y + 40)], fill=(255, 255, 255), width=4)
    d.line([(270, 340), (350, 340)], fill=(255, 255, 255), width=4)

    d.text((70, 560), "Картинка отдаётся напрямую из бакета Object Storage", font=sub, fill=(205, 235, 245))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"{OUT}: {OUT.stat().st_size} байт, {W}x{H}")


if __name__ == "__main__":
    main()
