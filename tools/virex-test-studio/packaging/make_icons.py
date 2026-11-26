"""Render the Studio artwork from its original geometry. Requires Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw


def main():
    assets = Path(__file__).resolve().parents[1] / "assets"
    assets.mkdir(exist_ok=True)
    image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((4, 4, 252, 252), radius=55, fill="#163C49")
    draw.polygon([(36, 61), (88, 61), (131, 148), (109, 197)], fill="#E1FAF0")
    draw.polygon([(146, 115), (175, 61), (221, 61), (144, 201), (113, 201)], fill="#69DBC6")
    icon_file = assets / "studio.ico"
    sizes = [(size, size) for size in (16, 24, 32, 48, 64, 128, 256)]
    image.save(icon_file, sizes=sizes)
    with Image.open(icon_file) as icon:
        preview = icon.ico.getimage((256, 256)).resize((96, 96), Image.Resampling.LANCZOS)
        preview.save(assets / "studio.png")


if __name__ == "__main__":
    main()
