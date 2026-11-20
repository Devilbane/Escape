"""Cuts the temple's wall blocks out of the Modular Cathedral Kit's trim sheet.

The trim sheet (assets/chapel/trim_sheet.png) holds the stone blocks the
temple's walls are laid in as a band of four courses. This keeps those four
courses, from just under the mortar line above the first to the mortar line
under the last, so the picture repeats up a wall without a seam (and it
repeats sideways as the sheet does). The house builder lays the stone of the
player's houses with it (see HouseLooks.temple_stone): four courses to a
wall's height.

Writes assets/house/temple_blocks.png. Needs Pillow.
Run: python3 tools/make_temple_blocks.py"""
import os
from PIL import Image

HERE = os.path.dirname(__file__)
SHEET = os.path.join(HERE, "..", "assets", "chapel", "trim_sheet.png")
OUT = os.path.join(HERE, "..", "assets", "house", "temple_blocks.png")
# The rows of the four courses on the 512 px sheet.
TOP, BOTTOM = 309, 470

Image.open(SHEET).convert("RGB").crop((0, TOP, 512, BOTTOM)).save(OUT)
print("wrote", OUT)
