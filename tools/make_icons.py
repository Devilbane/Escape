#!/usr/bin/env python3
"""Draws the game's item and HUD icons as SVG files in assets/ui/icons/.

Each picture is drawn on a 64 x 64 grid and saved at 128 x 128, so Godot
imports it sharp enough for the largest place it is shown. ItemIcon draws
<kind>.svg; where an item's own colour matters (a helmet's metal, a cloak's
cloth, a coin's metal...), a second file <kind>__tint.svg holds the part in
grey, which ItemIcon tints with that colour and draws under <kind>.svg.

Run from the repository root:  python3 tools/make_icons.py
Then open the project in Godot (or run `godot --headless --import`) so the new
files are imported.
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "icons")

# A dark ink outline around every shape, as in a woodcut.
O = 'stroke="#1b1108" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"'

DEFS = """<defs>
<linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f4f6fb"/><stop offset=".5" stop-color="#a9b0bd"/><stop offset="1" stop-color="#5d6470"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0b0"/><stop offset=".45" stop-color="#e2a93c"/><stop offset="1" stop-color="#8a5418"/></linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9b6236"/><stop offset=".5" stop-color="#6e3f1e"/><stop offset="1" stop-color="#4a2a12"/></linearGradient>
<linearGradient id="woodv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a86c3c"/><stop offset="1" stop-color="#5a3216"/></linearGradient>
<linearGradient id="leather" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b9783f"/><stop offset="1" stop-color="#5c3216"/></linearGradient>
<linearGradient id="grey" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".55" stop-color="#c8c8c8"/><stop offset="1" stop-color="#7a7a7a"/></linearGradient>
<radialGradient id="greyr" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#bdbdbd"/><stop offset="1" stop-color="#6e6e6e"/></radialGradient>
<radialGradient id="ruby" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#ffb3b3"/><stop offset=".4" stop-color="#e0263a"/><stop offset="1" stop-color="#5e0610"/></radialGradient>
<radialGradient id="red" cx=".35" cy=".3" r=".75"><stop offset="0" stop-color="#ff9a7a"/><stop offset=".45" stop-color="#d0281c"/><stop offset="1" stop-color="#6a0c08"/></radialGradient>
<radialGradient id="green" cx=".35" cy=".3" r=".75"><stop offset="0" stop-color="#b8ffb0"/><stop offset=".5" stop-color="#3fa83a"/><stop offset="1" stop-color="#14401a"/></radialGradient>
<radialGradient id="flame" cx=".5" cy=".8" r=".8"><stop offset="0" stop-color="#fff6c0"/><stop offset=".4" stop-color="#ffb02e"/><stop offset="1" stop-color="#d23a0c"/></radialGradient>
<radialGradient id="violet" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="#f1dcff"/><stop offset=".5" stop-color="#a66cf0"/><stop offset="1" stop-color="#4b2286"/></radialGradient>
<radialGradient id="ice" cx=".4" cy=".3" r=".8"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#a9dcff"/><stop offset="1" stop-color="#3b7fb8"/></radialGradient>
<linearGradient id="parch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbeac0"/><stop offset="1" stop-color="#c9a466"/></linearGradient>
<linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d6d2c8"/><stop offset="1" stop-color="#6f6b64"/></linearGradient>
<radialGradient id="glass" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#ffffff" stop-opacity=".35"/><stop offset="1" stop-color="#b8d4e8" stop-opacity=".12"/></radialGradient>
</defs>"""

# kind -> (picture, tinted part or None). The tinted part is drawn in greys
# and lies under the picture.
ICONS = {
    "sword": (f'<path d="M54 6l4 4-30 32-6-6z" fill="url(#steel)" {O}/><path d="M54 8L27 37" stroke="#fff" stroke-width="1.2" opacity=".7"/>'
              f'<path d="M14 34l16 16" stroke="#1b1108" stroke-width="8" stroke-linecap="round"/><path d="M14 34l16 16" stroke="url(#gold)" stroke-width="5" stroke-linecap="round"/>'
              f'<path d="M22 42L12 52" stroke="#1b1108" stroke-width="8" stroke-linecap="round"/><path d="M22 42L12 52" stroke="#6e3f1e" stroke-width="5" stroke-linecap="round"/>'
              f'<circle cx="9" cy="55" r="4.5" fill="url(#gold)" {O}/>', None),
    "knife": (f'<path d="M56 6l2 4-22 24-6-4z" fill="url(#steel)" {O}/><path d="M55 8L33 31" stroke="#fff" stroke-width="1" opacity=".7"/>'
              f'<path d="M30 34L16 48" stroke="#1b1108" stroke-width="8" stroke-linecap="round"/><path d="M30 34L16 48" stroke="url(#leather)" stroke-width="5" stroke-linecap="round"/>'
              f'<path d="M22 40l4 4M18 44l4 4" stroke="#3b200c" stroke-width="1.5"/><circle cx="12" cy="52" r="5" fill="none" stroke="#1b1108" stroke-width="5"/><circle cx="12" cy="52" r="5" fill="none" stroke="url(#steel)" stroke-width="2.5"/>', None),
    "axe": (f'<path d="M28 6h6v52h-6z" fill="url(#wood)" {O}/><path d="M34 10c12 0 20 7 22 18-2 9-10 15-22 15z" fill="url(#steel)" {O}/>'
            f'<path d="M50 16c3 4 4 9 3 14" stroke="#fff" stroke-width="1.5" fill="none" opacity=".7"/><path d="M28 18c-5 1-8 4-9 8 1 4 4 7 9 8z" fill="url(#steel)" {O}/>', None),
    "hammer": (f'<path d="M14 54l24-28 5 4-24 28z" fill="url(#wood)" {O}/><path d="M28 14l12-8 18 22-12 8z" fill="url(#steel)" {O}/>'
               f'<path d="M32 13l9-6" stroke="#fff" stroke-width="1.5" opacity=".7"/>', None),
    "shield": (f'<circle cx="32" cy="32" r="25" fill="url(#wood)" {O}/><circle cx="32" cy="32" r="25" fill="none" stroke="url(#steel)" stroke-width="5"/>'
               f'<circle cx="32" cy="32" r="27.5" fill="none" stroke="#1b1108" stroke-width="1.5"/><path d="M32 9v46M9 32h46" stroke="#3b200c" stroke-width="1.5" opacity=".6"/>'
               f'<circle cx="32" cy="32" r="8" fill="url(#steel)" {O}/><circle cx="29.5" cy="29.5" r="2.5" fill="#fff" opacity=".7"/>', None),
    "helmet": (f'<path d="M12 40c0-17 9-28 20-28s20 11 20 28v10H40V38H24v12H12z" fill="none" {O}/><path d="M32 12v26" stroke="#000" stroke-opacity=".35" stroke-width="3"/>'
               f'<path d="M20 22c3-5 7-7 10-7" stroke="#fff" stroke-width="2" fill="none" opacity=".7"/><rect x="24" y="38" width="16" height="4" fill="#1b1108"/>'
               f'<path d="M12 46h12M40 46h12" stroke="url(#gold)" stroke-width="2.5"/>',
               '<path d="M12 40c0-17 9-28 20-28s20 11 20 28v10H40V38H24v12H12z" fill="url(#grey)"/>'),
    "cloak": (f'<path d="M24 8h16l4 8c6 10 10 26 10 40H10c0-14 4-30 10-40z" fill="none" {O}/><path d="M32 16v40M24 18c-4 10-6 24-6 38M40 18c4 10 6 24 6 38" stroke="#000" stroke-opacity=".35" stroke-width="1.5" fill="none"/>'
              f'<circle cx="32" cy="14" r="4" fill="url(#gold)" {O}/>',
              '<path d="M24 8h16l4 8c6 10 10 26 10 40H10c0-14 4-30 10-40z" fill="url(#grey)"/>'),
    "armour": (f'<path d="M20 8l12 6 12-6 12 10-6 10v28H14V28L8 18z" fill="none" {O}/><g fill="none" stroke="#000" stroke-opacity=".3" stroke-width="1.2"><path d="M16 30h32M16 36h32M16 42h32M16 48h32"/><path d="M20 28v28M26 28v28M32 28v28M38 28v28M44 28v28"/></g>'
               f'<path d="M20 8l12 6 12-6" fill="none" stroke="url(#gold)" stroke-width="3"/>',
               '<path d="M20 8l12 6 12-6 12 10-6 10v28H14V28L8 18z" fill="url(#grey)"/>'),
    "gloves": (f'<path d="M18 58V32l-6-10c-1-3 2-5 4-3l6 7V12a3 3 0 0 1 6 0v14V8a3 3 0 0 1 6 0v18V10a3 3 0 0 1 6 0v18V16a3 3 0 0 1 6 0v28c0 6-4 10-8 14z" fill="none" {O}/>'
               f'<path d="M18 50h26" stroke="url(#gold)" stroke-width="3"/>',
               '<path d="M18 58V32l-6-10c-1-3 2-5 4-3l6 7V12a3 3 0 0 1 6 0v14V8a3 3 0 0 1 6 0v18V10a3 3 0 0 1 6 0v18V16a3 3 0 0 1 6 0v28c0 6-4 10-8 14z" fill="url(#grey)"/>'),
    "boots": (f'<path d="M14 10h16v28l14 6c6 2 8 6 8 10H14z" fill="none" {O}/><path d="M14 50h38v6H14z" fill="#3b200c" {O}/><path d="M14 18h16" stroke="#000" stroke-opacity=".35" stroke-width="3"/>'
              f'<path d="M18 14v20" stroke="#fff" stroke-width="1.5" opacity=".45"/>',
              '<path d="M14 10h16v28l14 6c6 2 8 6 8 10H14z" fill="url(#grey)"/>'),
    "amulet": (f'<path d="M14 8c0 16 8 24 18 26M50 8c0 16-8 24-18 26" fill="none" stroke="url(#gold)" stroke-width="3"/><circle cx="32" cy="42" r="14" fill="url(#gold)" {O}/>'
               f'<circle cx="32" cy="42" r="8" fill="url(#ice)" {O}/><circle cx="29" cy="39" r="2.5" fill="#fff" opacity=".8"/>', None),
    "ring": (f'<ellipse cx="32" cy="38" rx="17" ry="15" fill="none" stroke="#1b1108" stroke-width="9"/><ellipse cx="32" cy="38" rx="17" ry="15" fill="none" stroke="url(#gold)" stroke-width="6"/>'
             f'<path d="M24 22l8-10 8 10-8 6z" fill="none" {O}/><path d="M28 18l4-4" stroke="#fff" stroke-width="1.5" opacity=".8"/>',
             '<path d="M24 22l8-10 8 10-8 6z" fill="url(#greyr)"/>'),
    "bracelet": (f'<ellipse cx="32" cy="34" rx="22" ry="16" fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="1.5" transform="translate(-1 -3)"/>'
                 f'<circle cx="32" cy="18" r="4" fill="url(#ice)" {O}/>',
                 '<ellipse cx="32" cy="34" rx="22" ry="16" fill="none" stroke="#1b1108" stroke-width="12"/>'
                 '<ellipse cx="32" cy="34" rx="22" ry="16" fill="none" stroke="url(#grey)" stroke-width="8"/>'),
    "special": (f'<path d="M32 4l7 18 19 1-15 12 6 19-17-11-17 11 6-19L6 23l19-1z" fill="url(#violet)" {O}/><path d="M32 12l4 12" stroke="#fff" stroke-width="2" opacity=".6"/>', None),
    "bag": (f'<path d="M16 22c0-8 7-14 16-14s16 6 16 14v30a4 4 0 0 1-4 4H20a4 4 0 0 1-4-4z" fill="none" {O}/><path d="M20 26h24v14H20z" fill="#000" fill-opacity=".2" {O}/>'
            f'<path d="M32 26v18" stroke="#1b1108" stroke-width="2"/><rect x="29" y="38" width="6" height="6" fill="url(#gold)" {O}/><path d="M24 10c0-4 4-6 8-6s8 2 8 6" fill="none" stroke="#3b200c" stroke-width="3"/>',
            '<path d="M16 22c0-8 7-14 16-14s16 6 16 14v30a4 4 0 0 1-4 4H20a4 4 0 0 1-4-4z" fill="url(#grey)"/>'),
    "book": (f'<path d="M12 10h34a6 6 0 0 1 6 6v38H18a6 6 0 0 1-6-6z" fill="#6b1a1a" {O}/><path d="M18 48h34v6H18a3 3 0 0 1 0-6z" fill="url(#parch)" {O}/>'
             f'<rect x="22" y="18" width="22" height="18" rx="2" fill="none" stroke="url(#gold)" stroke-width="2.5"/><path d="M33 21v12M28 26h10" stroke="url(#gold)" stroke-width="2.5"/>', None),
    "scroll": (f'<rect x="14" y="12" width="36" height="40" fill="url(#parch)" {O}/><rect x="10" y="6" width="44" height="9" rx="4.5" fill="url(#wood)" {O}/>'
               f'<rect x="10" y="49" width="44" height="9" rx="4.5" fill="url(#wood)" {O}/><path d="M20 24h24M20 30h24M20 36h18" stroke="#6e4a20" stroke-width="2"/>', None),
    "stone": (f'<path d="M8 26l10-10h40l-8 10z" fill="#e3dfd6" {O}/><path d="M8 26h42v26H8z" fill="url(#stone)" {O}/><path d="M50 26l8-10v26l-8 10z" fill="#77736b" {O}/>'
              f'<path d="M14 36h10M30 44h12" stroke="#5a564f" stroke-width="1.5"/>', None),
    "coal": (f'<path d="M10 46l6-20 16-12 18 8 6 22-20 10z" fill="#2a2726" {O}/><path d="M22 28l12-8 10 4" stroke="#8a8582" stroke-width="2" fill="none"/><path d="M40 40l6 4" stroke="#e05a20" stroke-width="2" opacity=".7"/>', None),
    "lime": (f'<path d="M10 46l6-20 16-12 18 8 6 22-20 10z" fill="url(#stone)" {O}/><path d="M22 28l12-8 10 4" stroke="#fff" stroke-width="2" fill="none" opacity=".8"/><circle cx="28" cy="40" r="2" fill="#a7a296"/><circle cx="42" cy="34" r="1.5" fill="#a7a296"/>', None),
    "ore": (f'<path d="M10 46l6-24 20-12 18 14-4 26-24 6z" fill="#5e5a55" {O}/><path d="M18 24l10-6" stroke="#9a958e" stroke-width="2"/>'
            f'<path d="M22 32l8 4-2 8-8-2zM38 22l8 2-1 7-8-1zM36 42l7 1-1 6-7-1z" fill="none" stroke="#1b1108" stroke-width="1.2"/>',
            '<path d="M22 32l8 4-2 8-8-2zM38 22l8 2-1 7-8-1zM36 42l7 1-1 6-7-1z" fill="url(#greyr)"/>'),
    "gem": (f'<path d="M14 24l8-12h20l8 12-18 30z" fill="url(#ice)" {O}/><path d="M14 24h36M22 12l6 12 4 30M42 12l-6 12-4 30" stroke="#fff" stroke-width="1.2" fill="none" opacity=".75"/>', None),
    "crystal": (f'<path d="M8 56l4-8h40l4 8z" fill="#5f6370" {O}/><path d="M14 50l6-28 8 28z" fill="url(#ice)" {O}/><path d="M26 50l8-44 8 44z" fill="url(#ice)" {O}/>'
                f'<path d="M40 50l6-24 6 24z" fill="url(#ice)" {O}/><path d="M34 12l-3 30" stroke="#fff" stroke-width="1.5" opacity=".85"/>', None),
    "crate": (f'<rect x="10" y="12" width="44" height="42" fill="url(#woodv)" {O}/><path d="M10 12l44 42M10 26h44M10 40h44" stroke="#3b200c" stroke-width="2"/>'
              f'<path d="M10 12h44v42H10z" fill="none" stroke="url(#steel)" stroke-width="3"/>', None),
    "bar": (f'<path d="M6 46l10-14h46l-8 14z" fill="none" {O}/><path d="M16 32l4-8h36l6 8z" fill="none" {O}/><path d="M22 26h30" stroke="#fff" stroke-width="1.5" opacity=".7"/>'
            f'<path d="M6 46l10-14h46l-8 14z" fill="#000" fill-opacity=".25"/>',
            '<path d="M6 46l10-14h46l-8 14z" fill="url(#grey)"/><path d="M16 32l4-8h36l6 8z" fill="#ffffff"/>'),
    "hammer_anvil": (f'<path d="M6 30h52l-10 10-4 12h6v6H14v-6h6l-4-12z" fill="url(#steel)" {O}/><path d="M10 31h44" stroke="#fff" stroke-width="1.5" opacity=".7"/>'
                     f'<path d="M36 26l16-20" stroke="#1b1108" stroke-width="7" stroke-linecap="round"/><path d="M36 26l16-20" stroke="url(#wood)" stroke-width="4" stroke-linecap="round"/>'
                     f'<path d="M26 18l10-8 8 10-10 8z" fill="url(#steel)" {O}/>', None),
    "flame": (f'<path d="M32 4c8 10 18 18 16 32-1 10-8 20-16 20s-15-10-16-20c-1-10 6-14 8-24 3 4 4 6 8-8z" fill="url(#flame)" {O}/>'
              f'<path d="M32 30c4 5 8 10 6 16-1 4-4 6-6 6s-5-2-6-6c-1-6 4-8 6-16z" fill="#fff3b0" opacity=".85"/>', None),
    "torch": (f'<path d="M20 58l14-26 5 3-14 26z" fill="url(#wood)" {O}/><path d="M30 26l12 6-4 8-12-6z" fill="url(#leather)" {O}/>'
              f'<path d="M42 2c6 8 12 12 10 20-1 5-6 8-11 8s-10-3-10-8c-1-6 5-8 6-14 2 2 3 3 5-6z" fill="url(#flame)" {O}/>', None),
    "torch_out": (f'<path d="M20 58l14-26 5 3-14 26z" fill="url(#wood)" {O}/><path d="M30 26l12 6-4 8-12-6z" fill="#3a2c22" {O}/>'
                  f'<path d="M34 28l6 3" stroke="#77706a" stroke-width="2"/><path d="M40 18c2-4 0-6 2-10M36 20c-1-3 1-5 0-8" stroke="#8a8580" stroke-width="1.5" fill="none" opacity=".6"/>', None),
    "bedroll": (f'<rect x="6" y="20" width="36" height="28" fill="#4f6440" {O}/><circle cx="42" cy="34" r="16" fill="#6b8456" {O}/>'
                f'<path d="M42 34m-9 0a9 9 0 1 0 9-9M42 34m-4 0a4 4 0 1 0 4-4" stroke="#2f3d26" stroke-width="2" fill="none"/>'
                f'<path d="M20 17v34" stroke="#1b1108" stroke-width="7"/><path d="M20 17v34" stroke="url(#leather)" stroke-width="4"/>', None),
    "scissors": (f'<circle cx="18" cy="48" r="8" fill="none" stroke="#1b1108" stroke-width="6"/><circle cx="18" cy="48" r="8" fill="none" stroke="url(#gold)" stroke-width="3.5"/>'
                 f'<circle cx="46" cy="48" r="8" fill="none" stroke="#1b1108" stroke-width="6"/><circle cx="46" cy="48" r="8" fill="none" stroke="url(#gold)" stroke-width="3.5"/>'
                 f'<path d="M24 42L46 6l3 2-20 38zM40 42L18 6l-3 2 20 38z" fill="url(#steel)" {O}/><circle cx="32" cy="27" r="2.5" fill="url(#gold)" {O}/>', None),
    "needle": (f'<path d="M50 8l4 2L16 54l-4 2 2-4z" fill="url(#steel)" {O}/><ellipse cx="50" cy="10" rx="2" ry="1" fill="#1b1108" transform="rotate(-45 50 10)"/>'
               f'<path d="M52 8c8-6 8 12-4 14S28 40 40 48" stroke="#4466e0" stroke-width="2.5" fill="none"/>', None),
    "sausage": (f'<path d="M14 46c-6-6-2-14 6-18l20-14c8-6 18 2 12 10L32 44c-6 6-12 8-18 2z" fill="#9a4024" {O}/><path d="M22 34l16-12" stroke="#e8987a" stroke-width="3" opacity=".7"/>'
                f'<path d="M12 48l-4 4M52 16l4-4" stroke="#e8d0a0" stroke-width="2.5"/>', None),
    "apple": (f'<path d="M32 20c-6-4-20-3-20 14 0 14 9 22 14 22 3 0 4-2 6-2s3 2 6 2c5 0 14-8 14-22 0-17-14-18-20-14z" fill="url(#red)" {O}/>'
              f'<path d="M32 20c0-6 2-10 5-12" stroke="#4a2a12" stroke-width="3" fill="none"/><path d="M35 14c5-6 12-4 14-2-4 4-9 5-14 2z" fill="url(#green)" {O}/>'
              f'<ellipse cx="22" cy="30" rx="3" ry="5" fill="#fff" opacity=".5"/>', None),
    "salt": (f'<path d="M10 46l8-24 24-4 14 24-22 12z" fill="#ecebe6" {O}/><path d="M18 22l16 32M30 30l12-6" stroke="#b8b6b0" stroke-width="1.5"/>'
             f'<path d="M24 28l8 4" stroke="#fff" stroke-width="3"/>', None),
    "seeds": ("".join(f'<ellipse cx="{x}" cy="{y}" rx="7" ry="4.5" transform="rotate({r} {x} {y})" fill="#dcb05c" {O}/><ellipse cx="{x-2}" cy="{y-1}" rx="2" ry="1.2" fill="#fbe7b0"/>'
                     for x, y, r in [(20, 46, 20), (32, 48, -10), (44, 46, 25), (26, 36, -25), (38, 36, 15), (32, 26, 0)]), None),
    "heal_potion": (f'<path d="M26 8h12v12c8 3 14 10 14 20 0 11-9 18-20 18S12 51 12 40c0-10 6-17 14-20z" fill="url(#glass)" {O}/>'
                    f'<rect x="24" y="4" width="16" height="7" rx="2" fill="url(#wood)" {O}/><path d="M20 30c2-4 4-6 6-7" stroke="#fff" stroke-width="2" fill="none" opacity=".8"/>',
                    '<path d="M14 40c0-4 6-6 18-4s18 0 18 4c0 10-8 16-18 16S14 50 14 40z" fill="url(#greyr)"/>'),
    "potion": (f'<path d="M26 8h12v12c8 3 14 10 14 20 0 11-9 18-20 18S12 51 12 40c0-10 6-17 14-20z" fill="url(#glass)" {O}/>'
               f'<path d="M14 40c0-4 6-6 18-4s18 0 18 4c0 10-8 16-18 16S14 50 14 40z" fill="url(#green)"/>'
               f'<rect x="24" y="4" width="16" height="7" rx="2" fill="url(#gold)" {O}/><path d="M20 30c2-4 4-6 6-7" stroke="#fff" stroke-width="2" fill="none" opacity=".8"/>', None),
    "map": (f'<path d="M8 14l16-6 16 6 16-6v42l-16 6-16-6-16 6z" fill="url(#parch)" {O}/><path d="M24 8v42M40 14v42" stroke="#8a6a3a" stroke-width="1.5"/>'
            f'<path d="M14 40c6-2 8-10 16-12s10-8 18-10" fill="none" stroke="#b02a1a" stroke-width="2.5" stroke-dasharray="3 3"/><path d="M44 16l4 4m0-4l-4 4" stroke="#b02a1a" stroke-width="2.5"/>', None),
    "hero": (f'<circle cx="32" cy="20" r="10" fill="url(#gold)" {O}/><path d="M12 56c0-12 9-20 20-20s20 8 20 20z" fill="url(#gold)" {O}/>', None),
    "house": (f'<path d="M6 30L32 8l26 22z" fill="#9a3a22" {O}/><path d="M12 30h40v26H12z" fill="url(#parch)" {O}/><path d="M28 40h8v16h-8z" fill="url(#wood)" {O}/>'
              f'<path d="M16 36h8v7h-8zM40 36h8v7h-8z" fill="#f2c46d" {O}/>', None),
    "coin": (f'<circle cx="32" cy="32" r="23" fill="none" {O}/><circle cx="32" cy="32" r="17" fill="none" stroke="#000" stroke-opacity=".35" stroke-width="2"/>'
             f'<path d="M27 24h10M32 24v16M27 40h10" stroke="#000" stroke-opacity=".4" stroke-width="3"/>',
             '<circle cx="32" cy="32" r="23" fill="url(#greyr)"/>'),
    "herb": (f'<path d="M32 58V28" stroke="#4a2a12" stroke-width="3"/>' + "".join(
                 f'<ellipse cx="{x}" cy="{y}" rx="6" ry="12" transform="rotate({r} {x} {y})" fill="url(#green)" {O}/>'
                 for x, y, r in [(32, 14, 0), (20, 24, -40), (44, 24, 40), (22, 38, -60), (42, 38, 60)])
             + '<path d="M26 48h12" stroke="url(#gold)" stroke-width="3"/>', None),
    "flower": ("".join(f'<circle cx="{32 + 12 * c}" cy="{26 + 12 * s}" r="8" fill="#d6dcff" {O}/>'
                       for c, s in [(1, 0), (0.31, 0.95), (-0.81, 0.59), (-0.81, -0.59), (0.31, -0.95)])
               + f'<circle cx="32" cy="26" r="6" fill="url(#gold)" {O}/><path d="M32 40v20" stroke="#3f7a32" stroke-width="3"/>', None),
    "mushroom": (f'<path d="M26 32h12l2 24H24z" fill="#efe7d4" {O}/><path d="M6 34C8 18 20 10 32 10s24 8 26 24z" fill="#9a5a2c" {O}/>'
                 f'<circle cx="22" cy="22" r="3" fill="#e9c9a0"/><circle cx="38" cy="18" r="2.5" fill="#e9c9a0"/><circle cx="46" cy="28" r="2" fill="#e9c9a0"/>', None),
    "fish": (f'<path d="M6 32c8-12 24-16 38-8l12-10v36L44 40C30 48 14 44 6 32z" fill="url(#steel)" {O}/><circle cx="16" cy="29" r="2.5" fill="#1b1108"/>'
             f'<path d="M22 38c8 2 14 1 20-3" stroke="#5d6470" stroke-width="1.5" fill="none"/>', None),
    "key": (f'<circle cx="18" cy="22" r="11" fill="none" stroke="#1b1108" stroke-width="8"/><circle cx="18" cy="22" r="11" fill="none" stroke="url(#gold)" stroke-width="5"/>'
            f'<path d="M26 30l24 24M40 44l6-6M46 50l6-6" stroke="#1b1108" stroke-width="8" stroke-linecap="round"/><path d="M26 30l24 24M40 44l6-6M46 50l6-6" stroke="url(#gold)" stroke-width="5" stroke-linecap="round"/>', None),
}


def svg(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">{DEFS}{body}</svg>\n'


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for kind, (picture, tint) in ICONS.items():
        with open(os.path.join(OUT, kind + ".svg"), "w") as f:
            f.write(svg(picture))
        if tint:
            with open(os.path.join(OUT, kind + "__tint.svg"), "w") as f:
                f.write(svg(tint))
    print(len(ICONS), "icons in", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
