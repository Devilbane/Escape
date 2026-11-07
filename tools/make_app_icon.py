"""Builds the application icon from the devilbane logo: assets/logo/app_icon.png and
assets/logo/app_icon.ico (16, 32, 48, 64, 128, 256). Only the "db" emblem is used, on a dark
rounded tile: the HARDCORE lettering is unreadable at 16 px. Run: python3 tools/make_app_icon.py"""
from PIL import Image, ImageDraw, ImageFilter

SIZES = [16, 32, 48, 64, 128, 256]
S = 1024  # master size


def master():
    logo = Image.open("assets/logo/devilbane_logo.png").convert("RGBA")
    emblem = logo.crop((20, 0, 460, 392))  # the "db" and its star, without the lettering
    tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg = Image.new("RGBA", (S, S), (14, 10, 26, 255))
    # a soft blue glow behind the emblem
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((180, 180, S - 180, S - 180), fill=(40, 110, 230, 150))
    bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(120)))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=190, fill=255)
    tile.paste(bg, (0, 0), mask)
    w = int(S * 0.86)
    h = int(w * emblem.height / emblem.width)
    emb = emblem.resize((w, h), Image.LANCZOS)
    tile.alpha_composite(emb, ((S - w) // 2, (S - h) // 2 + 10))
    border = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle((6, 6, S - 7, S - 7), radius=186, outline=(90, 150, 255, 200), width=10)
    return Image.alpha_composite(tile, border)


if __name__ == "__main__":
    m = master()
    m.resize((256, 256), Image.LANCZOS).save("assets/logo/app_icon.png")
    m.save("assets/logo/app_icon.ico", sizes=[(s, s) for s in SIZES])
