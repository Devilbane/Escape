"""Builds the application icon from the devilbane logo: assets/logo/app_icon.png and
assets/logo/app_icon.ico (16, 32, 48, 64, 128, 256). Only the "db" emblem is used, on a dark
rounded tile: the HARDCORE lettering is unreadable at 16 px. The logo's star is erased and
tools/app_icon_sunrise.png (sun 2.4 times larger, with its lit landscape) rises halfway between the top of
the letters and the top edge of the tile. Run: python3 tools/make_app_icon.py"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZES = [16, 32, 48, 64, 128, 256]
SUN_ZOOM = 1.5 * 1.6  # the sunrise picture: enlarged 50%, then another 60%
S = 1024  # master size


def without_star(logo):
    """The logo with its star wiped off, so only the letters are left."""
    m = Image.new("L", logo.size, 255)
    d = ImageDraw.Draw(m)
    d.rectangle((0, 0, 480, 88), fill=0)
    d.rectangle((205, 88, 275, 112), fill=0)  # stubs of the star's diagonal rays
    d.rectangle((231, 88, 249, 150), fill=0)  # its lower spike between the letters
    m = m.filter(ImageFilter.GaussianBlur(5))
    logo = logo.copy()
    logo.putalpha(ImageChops.multiply(logo.getchannel("A"), m))
    return logo


def sunrise(width):
    """The sunrise picture, enlarged around the sun, as wide as the tile."""
    img = Image.open("tools/app_icon_sunrise.png").convert("RGB")
    sun = (530, 230)
    w, h = img.size
    box = (sun[0] - sun[0] / SUN_ZOOM, sun[1] - sun[1] / SUN_ZOOM, sun[0] + (w - sun[0]) / SUN_ZOOM, sun[1] + (h - sun[1]) / SUN_ZOOM)
    img = img.resize((w, h), Image.LANCZOS, box=box)
    k = width / w
    return img.resize((width, round(h * k)), Image.LANCZOS), (round(sun[0] * k), round(sun[1] * k))


def master():
    logo = without_star(Image.open("assets/logo/devilbane_logo.png").convert("RGBA"))
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
    # the sun halfway between the letters' upper rim and the tile's upper edge
    top = (S - h) // 2 + 10 + round(94 * w / emblem.width)  # the letters start 94 px down in the logo
    pic, (sx, sy) = sunrise(S)
    glow_layer = Image.new("RGB", (S, S), (0, 0, 0))
    glow_layer.paste(pic, (S // 2 - sx, top // 2 - sy))
    lit = ImageChops.screen(tile.convert("RGB"), glow_layer)
    tile = Image.composite(lit.convert("RGBA"), tile, mask)
    border = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle((6, 6, S - 7, S - 7), radius=186, outline=(90, 150, 255, 200), width=10)
    return Image.alpha_composite(tile, border)


if __name__ == "__main__":
    m = master()
    m.resize((256, 256), Image.LANCZOS).save("assets/logo/app_icon.png")
    m.save("assets/logo/app_icon.ico", sizes=[(s, s) for s in SIZES])
