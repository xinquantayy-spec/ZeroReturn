"""Zero Return skyboxes (audit art.2): an original hazy sky in three sets, clear, overcast and night.

The sky depends only on the height above the horizon, so the four side faces of a set are one image and each set
needs three uploads: side (SkyboxBk/Ft/Lf/Rt), up (SkyboxUp) and down (SkyboxDn). Roblox's own Clouds layer stays on
top and the engine draws the sun, moon and stars, so nothing is baked in but the gradient and a faint grain against
banding. Colours: Tarkov's skies are pale and hazy, brightest at the horizon; ours sit in the BODYCAM grade
(World.luau's Atmosphere colour A9B4B1).

Writes assets/textures/sky/ZR_SKY_<set>_<face>.png (512 x 512) and a preview strip.
Run: python3 assets/textures/gen_sky.py
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sky")

# (elevation in degrees, RGB): below the horizon, the horizon haze band, up to the zenith
SETS = {
    "clear": [(-90, (112, 118, 116)), (-4, (150, 156, 152)), (0, (196, 202, 198)), (6, (178, 190, 192)),
              (20, (140, 160, 172)), (45, (110, 136, 156)), (90, (92, 120, 144))],
    "overcast": [(-90, (98, 102, 100)), (-4, (132, 136, 134)), (0, (176, 180, 178)), (8, (164, 169, 169)),
                 (30, (146, 151, 153)), (90, (126, 131, 134))],
    "night": [(-90, (6, 7, 8)), (-4, (14, 16, 18)), (0, (34, 39, 46)), (6, (24, 29, 37)), (25, (14, 18, 27)),
              (90, (7, 10, 17))],
}


def colour(stops, elev):
    """elev: array of degrees -> (..., 3) float RGB by linear interpolation between the stops"""
    xs = np.array([s[0] for s in stops], dtype=float)
    out = np.zeros(elev.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(elev, xs, [s[1][c] for s in stops])
    return out


def face(stops, kind, rng):
    t = (np.arange(N) + 0.5) / N * 2 - 1  # -1..1 across the face
    u, v = np.meshgrid(t, t)  # v grows downwards in the image
    if kind == "side":
        x, y, z = u, -v, np.ones_like(u)
    elif kind == "up":
        x, y, z = u, np.ones_like(u), v
    else:
        x, y, z = u, -np.ones_like(u), v
    elev = np.degrees(np.arctan2(y, np.sqrt(x * x + z * z)))
    rgb = colour(stops, elev)
    rgb += rng.uniform(-0.9, 0.9, rgb.shape)  # dither: an 8-bit gradient bands without it
    return Image.fromarray(rgb.clip(0, 255).round().astype(np.uint8), "RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(7)
    strips = []
    for name, stops in SETS.items():
        imgs = {}
        for kind in ("side", "up", "down"):
            img = face(stops, kind, rng)
            img.save(os.path.join(OUT, f"ZR_SKY_{name}_{kind}.png"), optimize=True)
            imgs[kind] = img
        # preview: four sides in a row with the up face over the second
        strip = Image.new("RGB", (N * 4, N * 3), (0, 0, 0))
        for i in range(4):
            strip.paste(imgs["side"], (i * N, N))
        strip.paste(imgs["up"], (N, 0))
        strip.paste(imgs["down"], (N, 2 * N))
        strips.append(strip.resize((N, int(N * 0.75))))
    prev = Image.new("RGB", (N * 3, int(N * 0.75)))
    for i, s in enumerate(strips):
        prev.paste(s, (i * N, 0))
    prev.save(os.path.join(OUT, "preview.png"))
    print("wrote", sorted(f for f in os.listdir(OUT) if f.endswith(".png")))


if __name__ == "__main__":
    main()
