"""Greyfang: 5 GECE - procedural texture generation (PIL + numpy).
Output: assets/textures/*.png   Run: python tools/gen_textures.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def value_noise(size, scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        g = r.random((s, s))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        out += np.asarray(img) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def save(name, arr):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def grime(size, seed, strength=0.35):
    n = value_noise(size, 4, 5, seed)
    return 1.0 - strength * np.clip((n - 0.45) * 2.5, 0, 1)


# Floor: worn cream & terracotta ceramic checker tiles (Turkish restaurant style)
S = 512
img = np.zeros((S, S, 3))
tiles = 4
ts = S // tiles
for i in range(tiles):
    for j in range(tiles):
        base = np.array([196, 182, 156]) if (i + j) % 2 == 0 else np.array([150, 78, 52])
        var = rng.uniform(-10, 10)
        img[i * ts:(i + 1) * ts, j * ts:(j + 1) * ts] = base + var
grout = 5
for k in range(tiles + 1):
    img[max(0, k * ts - grout // 2):k * ts + grout // 2 + 1, :] = [70, 64, 56]
    img[:, max(0, k * ts - grout // 2):k * ts + grout // 2 + 1] = [70, 64, 56]
g = grime(S, 1, 0.45)
fine = value_noise(S, 32, 3, 2)
img = img * g[..., None] * (0.9 + 0.2 * fine[..., None])
# cracks
pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(pil)
for _ in range(7):
    x, y = rng.integers(0, S, 2)
    pts = [(x, y)]
    for _ in range(rng.integers(4, 9)):
        x += rng.integers(-25, 25)
        y += rng.integers(-25, 25)
        pts.append((x, y))
    d.line(pts, fill=(55, 48, 42), width=1)
save("floor_tiles", np.asarray(pil))

# Wall tiles: small white glazed tiles, grimy lower part
img = np.ones((S, S, 3)) * np.array([205, 205, 196])
ts = 64
for k in range(0, S + 1, ts):
    img[max(0, k - 2):k + 2, :] = [120, 118, 108]
    img[:, max(0, k - 2):k + 2] = [120, 118, 108]
img *= grime(S, 3, 0.5)[..., None]
grad = np.linspace(0.85, 1.0, S)[::-1][:, None, None]
img *= grad
save("wall_tiles", img)

# Plaster wall (upper part), stained
n = value_noise(S, 6, 5, 4)
img = np.ones((S, S, 3)) * np.array([176, 160, 132]) * (0.75 + 0.35 * n[..., None])
stain = value_noise(S, 3, 4, 9)
img *= (1 - 0.35 * np.clip((stain - 0.55) * 3, 0, 1))[..., None]
save("plaster", img)

# Marble table top
n1 = value_noise(S, 3, 6, 5)
xx = np.linspace(0, 8 * np.pi, S)[None, :] + n1 * 12
veins = np.abs(np.sin(xx)) ** 0.25
img = np.ones((S, S, 3)) * np.array([226, 222, 214])
img *= (0.72 + 0.28 * veins)[..., None]
img *= (0.95 + 0.05 * value_noise(S, 40, 2, 6))[..., None]
save("marble", img)

# Dark wood
yy = np.linspace(0, 1, S)[:, None]
n2 = value_noise(S, 4, 5, 7)
rings = np.sin((yy * 40 + n2 * 6) * np.pi) * 0.5 + 0.5
img = np.ones((S, S, 3)) * np.array([92, 58, 36]) * (0.7 + 0.3 * rings[..., None])
save("wood", img)

# Brick / stone oven
img = np.ones((S, S, 3)) * np.array([60, 52, 46])
bh, bw = 48, 112
for row in range(0, S, bh):
    off = (row // bh % 2) * bw // 2
    for col in range(-bw, S + bw, bw):
        c = np.array([150, 70, 42]) * rng.uniform(0.6, 1.1)
        x0, x1 = col + off + 3, col + off + bw - 3
        y0, y1 = row + 3, row + bh - 3
        img[max(0, y0):max(0, min(S, y1)), max(0, x0):max(0, min(S, x1))] = c
img *= grime(S, 8, 0.6)[..., None]
soot = value_noise(S, 2, 3, 12)
img *= (1 - 0.6 * np.clip(soot - 0.3, 0, 1))[..., None]
save("brick", img)

# Concrete
n = value_noise(S, 8, 6, 13)
img = np.ones((S, S, 3)) * 110 * (0.7 + 0.5 * n[..., None])
save("concrete", img)

# Curtain fabric: dark purple with gold stars-like stripes
img = np.zeros((S, S, 3))
xx = np.linspace(0, 1, S)[None, :]
folds = 0.6 + 0.4 * np.sin(xx * 2 * np.pi * 10) ** 2
img[...] = np.array([70, 18, 50]) * folds[..., None]
for k in range(0, S, 64):
    img[:, k:k + 6] = np.array([150, 110, 40]) * folds[:, k:k + 6, None]
img *= grime(S, 14, 0.4)[..., None]
img = np.broadcast_to(img, (S, S, 3)).copy()
save("curtain", img)

# Metal (brushed, scratched)
n = value_noise(S, 64, 2, 15)
img = np.ones((S, S, 3)) * np.array([120, 124, 126]) * (0.8 + 0.25 * n[..., None])
for _ in range(120):
    y = rng.integers(0, S)
    img[y, :] *= rng.uniform(0.85, 1.15)
img *= grime(S, 16, 0.4)[..., None]
save("metal", img)

# Fur noise detail (grayscale, multiplied with character colors)
n = value_noise(S, 48, 4, 17)
stripes = value_noise(S, 6, 3, 18)
img = (0.75 + 0.35 * n) * (0.85 + 0.15 * stripes)
img *= grime(S, 19, 0.35)
img = np.stack([img * 255] * 3, -1)
save("fur", img)

# Stage backdrop: dark blue with stars & clouds-ish paint
img = np.ones((S, S, 3)) * np.array([22, 28, 60])
n = value_noise(S, 3, 4, 20)
img *= (0.7 + 0.6 * n[..., None])
pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(pil)
for _ in range(40):
    x, y = rng.integers(0, S, 2)
    r = rng.integers(3, 9)
    d.polygon([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r), (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)], fill=(200, 190, 140))
save("stage_backdrop", np.asarray(pil))

# Children's drawings (crayon scribbles of the band - abstract, no text)
for k in range(3):
    W, H = 256, 320
    pil = Image.new("RGB", (W, H), (236, 230, 214))
    d = ImageDraw.Draw(pil)
    cols = [(110, 110, 120), (120, 60, 160), (170, 90, 100), (30, 30, 30), (200, 170, 40)]
    for f in range(rng.integers(1, 3)):
        cx = rng.integers(60, 200)
        cy = rng.integers(110, 200)
        c = cols[rng.integers(len(cols))]
        d.ellipse([cx - 35, cy - 80, cx + 35, cy - 20], outline=c, width=4)
        d.rectangle([cx - 30, cy - 20, cx + 30, cy + 60], outline=c, width=4)
        d.line([cx - 30, cy, cx - 60, cy + 30], fill=c, width=4)
        d.line([cx + 30, cy, cx + 60, cy + 30], fill=c, width=4)
        d.ellipse([cx - 15, cy - 60, cx - 5, cy - 50], fill=(20, 20, 20))
        d.ellipse([cx + 5, cy - 60, cx + 15, cy - 50], fill=(20, 20, 20))
    for _ in range(30):
        x, y = rng.integers(0, W, 2)
        d.line([x, y, x + rng.integers(-12, 12), y + rng.integers(-12, 12)], fill=tuple(int(v) for v in rng.integers(80, 220, 3)), width=2)
    pil = pil.filter(ImageFilter.GaussianBlur(0.6))
    pil.save(os.path.join(OUT, f"drawing_{k}.png"))
    print("wrote drawing", k)

# Band poster from the official character concept art (labels strip cropped)
src = os.path.join(ROOT, "_references", "1.jpg")
if os.path.exists(src):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    im = im.crop((0, 0, w, int(h * 0.90)))
    im = im.resize((1024, int(1024 * im.size[1] / im.size[0])), Image.LANCZOS)
    arr = np.asarray(im).astype(float)
    # aged print look
    arr = arr * 0.85 + np.array([20, 12, 0])
    g = value_noise(arr.shape[0], 4, 4, 30)
    if g.shape[1] < arr.shape[1]:
        g = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((arr.shape[1], arr.shape[0]))) / 255.0
    arr *= (0.8 + 0.3 * g[: arr.shape[0], : arr.shape[1], None])
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "band_poster.jpg"), quality=88)
    print("wrote band_poster")
print("done")
