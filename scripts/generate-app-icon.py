#!/usr/bin/env python3
"""Generate the pixel-droplet AppIcon assets from a 16x16 sprite definition.

Outputs three 1024x1024 PNGs in SuiWidget/Resources/Assets.xcassets/AppIcon.appiconset/:
- icon-1024.png         (Sui-blue background, blue droplet sprite, light appearance)
- icon-1024-dark.png    (dark-paper background, same droplet)
- icon-1024-tinted.png  (transparent background, white droplet — for iOS 18+ tinted icons)

Run from repo root:
    python3 scripts/generate-app-icon.py
"""

from PIL import Image
import os

# 16x16 droplet sprite from pixel-core.jsx → PxDroplet.
# 1 = body, 2 = highlight, 3 = eye (white), 4 = mouth (shadow), 0 = empty.
SPRITE = [
    [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,1,2,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,2,2,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,2,0,0,0,0,0,0],
    [0,0,0,0,0,1,1,1,1,2,2,0,0,0,0,0],
    [0,0,0,0,0,1,1,1,1,1,2,0,0,0,0,0],
    [0,0,0,0,1,1,3,1,1,3,1,2,0,0,0,0],
    [0,0,0,0,1,1,3,1,1,3,1,2,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,2,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,2,0,0,0],
    [0,0,1,1,1,1,1,4,4,1,1,1,1,2,0,0],
    [0,0,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
    [0,0,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
]

# Color tables.
SUI_BLUE      = (77, 162, 255, 255)   # body
SUI_HIGHLIGHT = (157, 208, 255, 255)  # lighter pixel rim
WHITE         = (255, 255, 255, 255)
DARK_MOUTH    = (31, 107, 181, 255)   # subtle shadow
SUI_BG_LIGHT  = (77, 162, 255, 255)   # full Sui blue background
SUI_BG_DARK   = (15, 20, 24, 255)     # paperDark
TRANSPARENT   = (0, 0, 0, 0)


def render_sprite(palette_overrides=None, background=SUI_BG_LIGHT, transparent_bg=False):
    """Render the 16x16 sprite onto a 1024x1024 canvas with nearest-neighbor upscaling."""
    palette = {
        1: SUI_BLUE,
        2: SUI_HIGHLIGHT,
        3: WHITE,
        4: DARK_MOUTH,
    }
    if palette_overrides:
        palette.update(palette_overrides)

    sprite_img = Image.new("RGBA", (16, 16), TRANSPARENT)
    for y, row in enumerate(SPRITE):
        for x, val in enumerate(row):
            if val == 0:
                continue
            sprite_img.putpixel((x, y), palette[val])

    # Upscale sprite to 768x768 (so it fits within the 1024 canvas with padding).
    sprite_up = sprite_img.resize((768, 768), Image.NEAREST)

    canvas = Image.new("RGBA", (1024, 1024), TRANSPARENT if transparent_bg else background)
    # Center the sprite on the canvas.
    canvas.paste(sprite_up, (128, 128), sprite_up)
    return canvas


def main():
    out_dir = "SuiWidget/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(out_dir, exist_ok=True)

    # Light: blue droplet on solid Sui-blue bg.
    light = render_sprite(background=SUI_BG_LIGHT)
    light.save(os.path.join(out_dir, "icon-1024.png"), "PNG")
    print(f"Wrote {out_dir}/icon-1024.png")

    # Dark: same droplet on dark-paper bg.
    dark = render_sprite(background=SUI_BG_DARK)
    dark.save(os.path.join(out_dir, "icon-1024-dark.png"), "PNG")
    print(f"Wrote {out_dir}/icon-1024-dark.png")

    # Tinted (iOS 18+): all-white droplet, transparent bg.
    tinted = render_sprite(
        palette_overrides={
            1: WHITE,
            2: WHITE,
            3: WHITE,
            4: WHITE,
        },
        transparent_bg=True,
    )
    tinted.save(os.path.join(out_dir, "icon-1024-tinted.png"), "PNG")
    print(f"Wrote {out_dir}/icon-1024-tinted.png")


if __name__ == "__main__":
    main()
