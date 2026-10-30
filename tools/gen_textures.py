#!/usr/bin/env python3
"""
Procedural texture generator for Traingame.

Every texture in assets/textures is made by this script (numpy + OpenCV + Pillow),
so you can tweak colours / scales here and re-run:

    python3 tools/gen_textures.py            # all textures
    python3 tools/gen_textures.py ballast    # just one (name prefix)

All terrain / material textures tile seamlessly (spectral noise and periodic
Worley noise wrap around the edges). Normal maps are OpenGL style (Y+), which is
what Godot expects.
"""
import os
import sys
import math
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
from scipy.spatial import cKDTree

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


# ----------------------------------------------------------------------------- noise
def spectral(n, beta=2.0, seed=0, aniso=(1.0, 1.0), fmin=0.0, fmax=1e9):
    """Seamless fractal noise by spectral synthesis (1/f^beta power spectrum).
    aniso=(small, 1) gives features stretched vertically, (1, small) horizontally."""
    r = np.random.default_rng(seed)
    F = np.fft.fft2(r.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / f ** (beta / 2.0)
    amp[(f < fmin) | (f > fmax)] = 0.0
    amp[0, 0] = 0.0
    out = np.real(np.fft.ifft2(F * amp))
    out -= out.mean()
    s = out.std()
    return out / (s if s > 0 else 1.0)


def norm01(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def worley(n, count, seed=0, jitter_y=1.0):
    """Periodic Worley noise. Returns (F1, F2, id) with distances in pixels."""
    r = np.random.default_rng(seed)
    pts = r.random((count, 2)) * n
    pts[:, 1] *= jitter_y
    pts[:, 1] %= n
    tree = cKDTree(pts, boxsize=n)
    yy, xx = np.mgrid[0:n, 0:n]
    q = np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], axis=1)
    d, i = tree.query(q, k=2)
    return d[:, 0].reshape(n, n), d[:, 1].reshape(n, n), i[:, 0].reshape(n, n)


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -dx * strength
    ny = dy * strength          # OpenGL convention: green = up in the image
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], axis=-1) * 0.5 + 0.5


def lerp(a, b, t):
    return a + (b - a) * t


def colorize(t, stops):
    """Map 0..1 scalar field through colour stops [(pos, (r,g,b)), ...]."""
    out = np.zeros(t.shape + (3,), np.float32)
    pos = [s[0] for s in stops]
    cols = [np.array(s[1], np.float32) for s in stops]
    for k in range(3):
        out[..., k] = np.interp(t, pos, [c[k] for c in cols])
    return out


def save_rgb(name, rgb, jpg=True, q=92):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    path = os.path.join(OUT, name + (".jpg" if jpg else ".png"))
    if jpg:
        img.save(path, quality=q, subsampling=0)
    else:
        img.save(path, optimize=True)
    print("  wrote", os.path.relpath(path))


def save_rgba(name, rgba):
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print("  wrote", os.path.relpath(path))


def save_gray(name, g, jpg=False):
    img = Image.fromarray((np.clip(g, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
    path = os.path.join(OUT, name + (".jpg" if jpg else ".png"))
    img.save(path, **({"quality": 92} if jpg else {"optimize": True}))
    print("  wrote", os.path.relpath(path))


def save_normal(name, h, strength, size=None):
    nm = normal_from_height(h, strength)
    if size and size != h.shape[0]:
        nm = cv2.resize(nm, (size, size), interpolation=cv2.INTER_AREA)
    save_rgb(name, nm, jpg=False)


def wrap_strokes(canvas, n, strokes, draw):
    """Draw strokes that wrap around tile edges (seamless)."""
    for s in strokes:
        x, y = s[0], s[1]
        reach = s[2] + 4
        offs_x = [0] + ([n] if x < reach else []) + ([-n] if x > n - reach else [])
        offs_y = [0] + ([n] if y < reach else []) + ([-n] if y > n - reach else [])
        for ox in offs_x:
            for oy in offs_y:
                draw(canvas, s, ox, oy)


# ------------------------------------------------------------------------ terrain
def tex_grass(name, n, base_cols, blade_cols, seed, dry=0.0):
    macro = norm01(spectral(n, 2.6, seed))
    mid = norm01(spectral(n, 1.6, seed + 1, fmin=8))
    t = np.clip(macro * 0.6 + mid * 0.4, 0, 1)
    rgb = colorize(t, base_cols)
    h = mid * 0.3
    r = np.random.default_rng(seed + 2)
    count = int(n * n / 14)
    strokes = []
    for _ in range(count):
        x, y = r.random() * n, r.random() * n
        L = r.uniform(6, 20) * n / 1024
        a = r.uniform(0, math.pi * 2)
        c = blade_cols[r.integers(len(blade_cols))]
        shade = r.uniform(0.75, 1.2)
        strokes.append((x, y, L, a, c, shade))
    hb = np.zeros((n, n), np.float32)

    def draw(cv, s, ox, oy):
        x, y, L, a, c, shade = s
        p0 = (int((x + ox) * 4), int((y + oy) * 4))
        p1 = (int((x + ox + math.cos(a) * L) * 4), int((y + oy + math.sin(a) * L) * 4))
        col = tuple(float(v * shade) for v in c)
        cv2.line(cv, p0, p1, col, 2, cv2.LINE_AA, 2)
        cv2.line(hb, p0, p1, float(shade), 2, cv2.LINE_AA, 2)

    blades = np.zeros((n, n, 3), np.float32)
    wrap_strokes(blades, n, strokes, draw)
    mask = np.clip(hb, 0, 1)[..., None]
    # blades over a darker, shadowed thatch
    rgb = rgb * 0.72 * (1 - mask) + blades * mask
    # dry tips / bleached patches
    if dry > 0:
        patch = norm01(spectral(n, 2.2, seed + 7)) ** 2
        rgb = lerp(rgb, rgb * np.array([1.18, 1.1, 0.82]), (patch * dry)[..., None])
    h = h + hb * 0.7
    return rgb, h


def make_terrain():
    n = 1024
    print("terrain")
    rgb, h = tex_grass("grass_dry", n,
        [(0.0, (0.36, 0.33, 0.17)), (0.5, (0.52, 0.47, 0.26)), (1.0, (0.62, 0.56, 0.33))],
        [(0.72, 0.64, 0.38), (0.6, 0.55, 0.3), (0.45, 0.47, 0.24), (0.8, 0.72, 0.48), (0.38, 0.4, 0.2)], 11, dry=0.6)
    save_rgb("grass_dry_albedo", rgb)
    save_normal("grass_dry_normal", h, 2.5, 512)
    rgb, h = tex_grass("grass_green", n,
        [(0.0, (0.16, 0.25, 0.08)), (0.5, (0.24, 0.36, 0.12)), (1.0, (0.33, 0.44, 0.17))],
        [(0.28, 0.42, 0.13), (0.22, 0.36, 0.1), (0.36, 0.48, 0.17), (0.18, 0.3, 0.08), (0.42, 0.5, 0.2)], 21, dry=0.15)
    save_rgb("grass_green_albedo", rgb)
    save_normal("grass_green_normal", h, 2.5, 512)

    # leaf litter / bare earth (NSW bush floor)
    base = norm01(spectral(n, 2.2, 31))
    rgb = colorize(base, [(0, (0.24, 0.18, 0.12)), (0.5, (0.36, 0.27, 0.18)), (1, (0.46, 0.36, 0.25))])
    h = base * 0.3
    r = np.random.default_rng(32)
    leaf_layer = np.zeros((n, n, 3), np.float32)
    leaf_h = np.zeros((n, n), np.float32)
    cols = [(0.55, 0.42, 0.28), (0.4, 0.3, 0.2), (0.62, 0.5, 0.36), (0.5, 0.45, 0.35), (0.35, 0.22, 0.14), (0.68, 0.58, 0.44)]
    strokes = []
    for _ in range(9000):
        strokes.append((r.random() * n, r.random() * n, 14, r.uniform(0, 180), cols[r.integers(len(cols))], r.uniform(3, 9), r.uniform(1, 2.2)))

    def draw_leaf(cv, s, ox, oy):
        x, y, _, ang, c, L, W = s
        center = (int((x + ox) * 4), int((y + oy) * 4))
        cv2.ellipse(cv, center, (int(L * 4), int(W * 4)), ang, 0, 360, c, -1, cv2.LINE_AA, 2)
        cv2.ellipse(leaf_h, center, (int(L * 4), int(W * 4)), ang, 0, 360, 1.0, -1, cv2.LINE_AA, 2)

    wrap_strokes(leaf_layer, n, strokes, draw_leaf)
    m = np.clip(leaf_h, 0, 1)[..., None]
    rgb = rgb * (1 - m) + leaf_layer * m
    # twigs
    tw = np.zeros((n, n), np.float32)
    for _ in range(500):
        x, y = r.random() * n * 4, r.random() * n * 4
        a = r.uniform(0, math.pi)
        L = r.uniform(20, 60) * 4
        cv2.line(tw, (int(x), int(y)), (int(x + math.cos(a) * L), int(y + math.sin(a) * L)), 1.0, 2, cv2.LINE_AA, 2)
    rgb = lerp(rgb, np.array([0.2, 0.14, 0.09]), (tw * 0.8)[..., None])
    save_rgb("litter_albedo", rgb)
    save_normal("litter_normal", h + leaf_h * 0.6 + tw * 0.4, 3.0, 512)

    # sandstone (Hawkesbury): horizontal strata, cross-bedding and cracks
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    warp = spectral(n, 2.4, 41) * 18
    strata = np.sin((yy + warp) / n * math.pi * 2 * 9) * 0.5 + 0.5
    fine = norm01(spectral(n, 1.3, 42, fmin=20))
    f1, f2, cid = worley(n, 26, 43, 1.0)
    crack = np.clip(1.0 - (f2 - f1) / 3.0, 0, 1) ** 4 * (norm01(spectral(n, 2.0, 47)) > 0.45)
    cellshade = (np.random.default_rng(44).random(26)[cid] - 0.5) * 0.12
    bedding = (np.sin((yy + warp * 0.5) / n * math.pi * 2 * 34) * 0.5 + 0.5) ** 8
    t = np.clip(strata * 0.45 + fine * 0.35 + norm01(spectral(n, 2.0, 45)) * 0.3 + cellshade, 0, 1)
    rgb = colorize(t, [(0, (0.5, 0.33, 0.2)), (0.3, (0.7, 0.5, 0.3)), (0.6, (0.82, 0.66, 0.44)), (0.85, (0.88, 0.78, 0.6)), (1, (0.74, 0.6, 0.45))])
    iron = norm01(spectral(n, 2.0, 46)) ** 3
    rgb = lerp(rgb, np.array([0.55, 0.24, 0.1]), (iron * 0.5)[..., None])
    rgb *= (1 - crack * 0.5 - bedding * 0.18)[..., None]
    h = t * 0.6 + strata * 0.35 - crack * 0.8 - bedding * 0.3
    save_rgb("sandstone_albedo", rgb)
    save_normal("sandstone_normal", h, 5.0, 512)

    # ECML cutting: chalky clay / weathered limestone
    t = norm01(spectral(n, 2.0, 51) * 0.7 + spectral(n, 1.4, 52, fmin=16) * 0.3)
    f1, f2, cid = worley(n, 220, 53)
    pebbles = np.clip(1 - f1 / 9.0, 0, 1) ** 2 * (np.random.default_rng(54).random(220)[cid] > 0.6)
    rgb = colorize(t, [(0, (0.4, 0.36, 0.3)), (0.5, (0.6, 0.56, 0.48)), (1, (0.78, 0.75, 0.68))])
    rgb = lerp(rgb, np.array([0.85, 0.84, 0.8]), (pebbles * 0.7)[..., None])
    save_rgb("clay_albedo", rgb)
    save_normal("clay_normal", t * 0.5 + pebbles * 0.6, 4.0, 512)

    # cess gravel / ash path
    f1, f2, cid = worley(n, 9000, 61)
    stone = np.clip(1 - f1 / 6.0, 0, 1)
    shade = np.random.default_rng(62).random(9000)[cid]
    base = norm01(spectral(n, 2.0, 63))
    t = np.clip(stone * 0.5 + shade * 0.35 + base * 0.25, 0, 1)
    rgb = colorize(t, [(0, (0.22, 0.2, 0.18)), (0.5, (0.42, 0.39, 0.35)), (1, (0.62, 0.58, 0.52))])
    save_rgb("gravel_albedo", rgb)
    save_normal("gravel_normal", stone * 0.8 + base * 0.2, 4.0, 512)

    # ploughed field (furrows along x) and wheat stubble (rows along x)
    warp = spectral(n, 2.5, 71) * 6
    furrow = np.sin((yy + warp) / n * math.pi * 2 * 24) * 0.5 + 0.5
    clods = norm01(spectral(n, 1.2, 72, fmin=30))
    t = np.clip(furrow * 0.55 + clods * 0.45, 0, 1)
    rgb = colorize(t, [(0, (0.18, 0.12, 0.08)), (0.5, (0.32, 0.23, 0.15)), (1, (0.46, 0.35, 0.24))])
    save_rgb("plough_albedo", rgb)
    save_normal("plough_normal", furrow * 0.8 + clods * 0.4, 5.0, 512)
    rows = (np.sin(yy / n * math.pi * 2 * 40) * 0.5 + 0.5) ** 3
    stalks = norm01(spectral(n, 0.8, 73, fmin=60, aniso=(0.2, 1.0)))
    t = np.clip(rows * 0.5 + stalks * 0.5, 0, 1)
    rgb = colorize(t, [(0, (0.38, 0.3, 0.16)), (0.5, (0.66, 0.56, 0.32)), (1, (0.84, 0.74, 0.48))])
    rgb = lerp(rgb, np.array([0.3, 0.38, 0.16]), (norm01(spectral(n, 2.4, 74)) ** 4 * 0.6)[..., None])
    save_rgb("stubble_albedo", rgb)
    save_normal("stubble_normal", rows * 0.6 + stalks * 0.4, 4.0, 512)

    # macro variation map (large scale tint / anti-tiling)
    m = 512
    mac = np.stack([norm01(spectral(m, 2.8, 81)), norm01(spectral(m, 2.2, 82)), norm01(spectral(m, 3.2, 83))], axis=-1)
    save_rgb("macro_variation", mac, jpg=False)


# -------------------------------------------------------------------------- track
def make_track():
    print("track")
    n = 1024
    # ballast: angular stones
    f1, f2, cid = worley(n, 2600, 101)
    edge = np.clip((f2 - f1) / 7.0, 0, 1)
    dome = np.clip(1 - f1 / 14.0, 0, 1)
    r = np.random.default_rng(102)
    shade = r.random(2600)[cid]
    tint = r.random(2600)[cid]
    grain = norm01(spectral(n, 1.0, 103, fmin=80))
    t = np.clip(0.35 + shade * 0.45 + grain * 0.2, 0, 1) * (0.35 + 0.65 * np.sqrt(edge))
    rgb = np.stack([t, t, t], -1) * np.where(tint[..., None] > 0.8, np.array([1.05, 0.98, 0.9]), np.array([0.98, 1.0, 1.04]))
    # rust/brake dust staining
    stain = norm01(spectral(n, 2.4, 104)) ** 2
    rgb = lerp(rgb, rgb * np.array([0.75, 0.55, 0.4]), (stain * 0.5)[..., None])
    save_rgb("ballast_albedo", rgb)
    save_normal("ballast_normal", dome * 0.7 + np.sqrt(edge) * 0.6 + grain * 0.1, 6.0, 1024)

    n = 512
    # concrete sleeper / general concrete
    base = norm01(spectral(n, 1.8, 111))
    pores = (np.random.default_rng(112).random((n, n)) > 0.985).astype(np.float32)
    pores = cv2.GaussianBlur(pores, (3, 3), 0.7)
    t = np.clip(0.55 + base * 0.3 - pores * 1.5, 0, 1)
    stains = norm01(spectral(n, 2.6, 113)) ** 2
    rgb = np.stack([t, t * 0.99, t * 0.96], -1)
    rgb = lerp(rgb, rgb * np.array([0.7, 0.62, 0.52]), (stains * 0.5)[..., None])
    save_rgb("concrete_albedo", rgb)
    save_normal("concrete_normal", base * 0.3 - pores * 0.8, 3.0)

    # creosoted timber sleeper
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    grain = spectral(n, 1.5, 121, aniso=(1.0, 0.08))
    rings = np.sin((yy + spectral(n, 2.4, 122) * 25) / n * math.pi * 2 * 14 + grain * 1.5) * 0.5 + 0.5
    cracks = (norm01(spectral(n, 1.2, 123, aniso=(1.0, 0.03))) > 0.94).astype(np.float32)
    t = np.clip(rings * 0.4 + norm01(grain) * 0.6, 0, 1)
    rgb = colorize(t, [(0, (0.12, 0.09, 0.07)), (0.5, (0.22, 0.17, 0.12)), (1, (0.33, 0.26, 0.19))])
    rgb *= (1 - cracks * 0.7)[..., None]
    weather = norm01(spectral(n, 2.2, 124))
    rgb = lerp(rgb, np.array([0.36, 0.33, 0.3]), (weather ** 3 * 0.5)[..., None])
    save_rgb("timber_albedo", rgb)
    save_normal("timber_normal", t * 0.5 - cracks * 1.0, 4.0)

    # rail web rust
    t = norm01(spectral(n, 1.6, 131))
    rgb = colorize(t, [(0, (0.2, 0.1, 0.06)), (0.5, (0.36, 0.2, 0.11)), (1, (0.5, 0.31, 0.18))])
    save_rgb("rust_albedo", rgb)

    # platform paving slabs
    slab = 128
    lines = ((xx % slab) < 2) | ((yy % slab) < 2)
    base = norm01(spectral(n, 1.6, 141))
    idx = (xx // slab + (yy // slab) * 7).astype(int)
    tone = np.random.default_rng(142).random(64)[idx % 64]
    t = np.clip(0.5 + base * 0.25 + tone * 0.15, 0, 1)
    t[lines] *= 0.55
    rgb = np.stack([t, t * 0.98, t * 0.95], -1)
    save_rgb("paving_albedo", rgb)
    save_normal("paving_normal", base * 0.2 - lines.astype(np.float32) * 0.6, 3.0)


# --------------------------------------------------------------------- vegetation
def leaf_cluster(n, seed, kind):
    """Leaf cluster card (RGBA) drawn at 2x and downsampled."""
    S = n * 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(seed)
    # bleed colour so alpha-tested edges don't go dark
    if kind == "gum":
        base_cols = [(0.42, 0.5, 0.38), (0.36, 0.44, 0.33), (0.5, 0.56, 0.42), (0.55, 0.52, 0.36), (0.3, 0.38, 0.28), (0.6, 0.45, 0.32)]
    elif kind == "oak":
        base_cols = [(0.2, 0.34, 0.12), (0.26, 0.4, 0.15), (0.17, 0.3, 0.1), (0.32, 0.45, 0.18), (0.22, 0.36, 0.14)]
    else:
        base_cols = [(0.2, 0.3, 0.14), (0.28, 0.36, 0.18), (0.24, 0.33, 0.16)]
    stems = []
    # main stems radiating from the card centre-top
    nst = 9 if kind == "gum" else 9
    for k in range(nst):
        if kind == "gum":
            a = math.pi / 2 + (k / (nst - 1) - 0.5) * 2.6 + r.uniform(-0.15, 0.15)
            L = r.uniform(0.32, 0.5) * S
            x0, y0 = S * 0.5 + r.uniform(-0.08, 0.08) * S, S * r.uniform(0.06, 0.16)
        else:
            a = r.uniform(0, math.pi * 2)
            L = r.uniform(0.25, 0.45) * S
            x0, y0 = S * 0.5 + r.uniform(-0.05, 0.05) * S, S * 0.5
        pts = [(x0, y0)]
        for j in range(6):
            a += r.uniform(-0.25, 0.25)
            x0 += math.cos(a) * L / 6
            y0 += math.sin(a) * L / 6
            pts.append((x0, y0))
        stems.append(pts)
        d.line(pts, fill=(70, 55, 40, 255), width=max(2, S // 300))
    count = 650 if kind == "gum" else 700
    for _ in range(count):
        st = stems[r.integers(len(stems))]
        p = st[r.integers(1, len(st))]
        c = base_cols[r.integers(len(base_cols))]
        shade = r.uniform(0.75, 1.15)
        col = tuple(int(min(255, v * shade * 255)) for v in c) + (255,)
        if kind == "gum":
            # lanceolate, sickle-shaped, hanging leaves
            L = r.uniform(0.07, 0.12) * S
            W = L * r.uniform(0.13, 0.19)
            p = (p[0] + r.uniform(-0.06, 0.06) * S, p[1] + r.uniform(-0.04, 0.04) * S)
            ang = math.pi / 2 + r.uniform(-0.8, 0.8)
            curve = r.uniform(-0.3, 0.3)
            poly = []
            for i in range(13):
                t = i / 12
                w = math.sin(t * math.pi) * W * (1 - 0.3 * t)
                ax = p[0] + math.cos(ang + curve * t) * L * t
                ay = p[1] + math.sin(ang + curve * t) * L * t
                nx, ny = -math.sin(ang), math.cos(ang)
                poly.append((ax + nx * w, ay + ny * w))
            for i in range(12, -1, -1):
                t = i / 12
                w = math.sin(t * math.pi) * W * (1 - 0.3 * t)
                ax = p[0] + math.cos(ang + curve * t) * L * t
                ay = p[1] + math.sin(ang + curve * t) * L * t
                nx, ny = -math.sin(ang), math.cos(ang)
                poly.append((ax - nx * w, ay - ny * w))
            d.polygon(poly, fill=col)
        else:
            L = r.uniform(0.04, 0.065) * S * (1.3 if kind == "oak" else 0.9)
            ang = r.uniform(0, math.pi * 2)
            ox, oy = p[0] + r.uniform(-0.12, 0.12) * S, p[1] + r.uniform(-0.12, 0.12) * S
            # lobed leaf: a few overlapping circles along the midrib
            for i in range(4):
                t = (i + 0.5) / 4
                cx, cy = ox + math.cos(ang) * L * t, oy + math.sin(ang) * L * t
                rr = L * (0.28 if i in (1, 2) else 0.2)
                d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=col)
    img = img.resize((n, n), Image.LANCZOS)
    a = np.asarray(img).astype(np.float32) / 255.0
    # colour bleed into transparent area (prevents dark halos with mipmaps)
    rgb = a[..., :3]
    alpha = a[..., 3]
    filled = rgb.copy()
    mask = alpha > 0.05
    for _ in range(12):
        blur = cv2.blur(filled * mask[..., None], (9, 9))
        wsum = cv2.blur(mask.astype(np.float32), (9, 9))
        grow = (~mask) & (wsum > 0.01)
        filled[grow] = blur[grow] / wsum[grow][..., None]
        mask = mask | grow
    # subtle per-leaf lighting variation
    filled *= (0.9 + 0.2 * norm01(spectral(n, 2.0, seed + 5)))[..., None]
    return np.concatenate([filled, alpha[..., None]], -1)


def grass_blades(n, seed, cols, dry_tips):
    S = n * 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(seed)
    for _ in range(110):
        x0 = r.uniform(0.04, 0.96) * S
        h = r.uniform(0.45, 0.98) * S
        w = r.uniform(0.008, 0.02) * S
        bend = r.uniform(-0.18, 0.18) * S
        c = np.array(cols[r.integers(len(cols))]) * r.uniform(0.8, 1.15)
        tip = c * 0.6 + np.array([0.75, 0.68, 0.45]) * 0.4 if dry_tips else c * 1.15
        steps = 10
        left, right = [], []
        for i in range(steps + 1):
            t = i / steps
            x = x0 + bend * t * t
            y = S - h * t
            ww = w * (1 - t) + 0.5
            left.append((x - ww, y))
            right.append((x + ww, y))
        for i in range(steps):
            t = (i + 0.5) / steps
            cc = c * (1 - t) + tip * t
            cc = cc * (0.65 + 0.35 * t)
            col = tuple(int(np.clip(v, 0, 1) * 255) for v in cc) + (255,)
            d.polygon([left[i], left[i + 1], right[i + 1], right[i]], fill=col)
    img = img.resize((n, n), Image.LANCZOS)
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    mask = alpha > 0.05
    filled = rgb.copy()
    for _ in range(10):
        blur = cv2.blur(filled * mask[..., None], (7, 7))
        wsum = cv2.blur(mask.astype(np.float32), (7, 7))
        grow = (~mask) & (wsum > 0.01)
        filled[grow] = blur[grow] / wsum[grow][..., None]
        mask = mask | grow
    return np.concatenate([filled, alpha[..., None]], -1)


def make_vegetation():
    print("vegetation")
    save_rgba("leaves_gum", leaf_cluster(1024, 201, "gum"))
    save_rgba("leaves_oak", leaf_cluster(1024, 202, "oak"))
    save_rgba("leaves_shrub", leaf_cluster(512, 203, "shrub"))
    save_rgba("grass_blades_dry", grass_blades(512, 211, [(0.55, 0.52, 0.28), (0.45, 0.46, 0.22), (0.62, 0.56, 0.32), (0.38, 0.42, 0.2)], True))
    save_rgba("grass_blades_green", grass_blades(512, 212, [(0.25, 0.4, 0.12), (0.2, 0.34, 0.1), (0.32, 0.46, 0.16), (0.28, 0.38, 0.12)], False))
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # smooth-barked gum: pale with soft peeling patches and vertical streaks
    a = norm01(spectral(n, 2.6, 221, aniso=(0.35, 1.0)))
    b = norm01(spectral(n, 2.2, 222, aniso=(0.35, 1.0)))
    streak = norm01(spectral(n, 1.6, 223, aniso=(0.06, 1.0)))
    rgb = colorize(a, [(0, (0.86, 0.84, 0.78)), (0.45, (0.74, 0.72, 0.67)), (0.7, (0.64, 0.62, 0.58)), (1, (0.55, 0.53, 0.5))])
    peel = np.clip((b - 0.62) * 6.0, 0, 1)
    rgb = lerp(rgb, np.array([0.76, 0.6, 0.44]), (peel * 0.75)[..., None])
    rgb = lerp(rgb, np.array([0.68, 0.46, 0.34]), (np.clip((b - 0.82) * 8.0, 0, 1) * 0.6)[..., None])
    rgb *= (0.88 + 0.2 * streak)[..., None]
    edge = np.abs(np.gradient(peel)[0]) + np.abs(np.gradient(peel)[1])
    save_rgb("bark_gum_albedo", rgb * (1 - np.clip(edge, 0, 1) * 0.25)[..., None])
    save_normal("bark_gum_normal", streak * 0.3 + peel * 0.25, 3.0)
    # rough furrowed oak bark
    furrows = norm01(spectral(n, 2.3, 231, aniso=(0.035, 1.0)))
    ridges = np.abs(np.sin(furrows * math.pi * 3))
    detail = norm01(spectral(n, 1.2, 232, fmin=40))
    t = np.clip(ridges * 0.7 + detail * 0.3, 0, 1)
    rgb = colorize(t, [(0, (0.08, 0.07, 0.06)), (0.5, (0.24, 0.21, 0.18)), (1, (0.4, 0.37, 0.33))])
    lichen = norm01(spectral(n, 2.2, 233)) ** 4
    rgb = lerp(rgb, np.array([0.45, 0.5, 0.35]), (lichen * 0.5)[..., None])
    save_rgb("bark_oak_albedo", rgb)
    save_normal("bark_oak_normal", t, 6.0)


# ----------------------------------------------------------------------- vehicles
def make_vehicle():
    print("vehicles")
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # generic paint weathering (multiply): grime collects low down and in streaks
    g = 1.0 - norm01(spectral(n, 2.4, 301)) ** 3 * 0.18
    streaks = norm01(spectral(n, 1.4, 302, aniso=(0.05, 1.0))) ** 4 * 0.12
    speck = (np.random.default_rng(303).random((n, n)) > 0.997).astype(np.float32)
    speck = cv2.GaussianBlur(speck, (3, 3), 0.8) * 0.4
    grime = np.clip(g - streaks - speck, 0, 1)
    save_gray("grime", grime)
    # brushed stainless steel normal (fine horizontal brushing)
    brush = spectral(n, 0.6, 311, aniso=(1.0, 0.02), fmin=30)
    save_normal("brushed_normal", brush * 0.04, 1.0)
    # teak with straight vertical grain (coach panels)
    grain = spectral(n, 1.6, 321, aniso=(1.0, 0.04))
    figure = np.sin((xx + spectral(n, 2.4, 322) * 30) / n * math.pi * 2 * 18 + grain * 2.0) * 0.5 + 0.5
    t = np.clip(norm01(grain) * 0.5 + figure * 0.5, 0, 1)
    rgb = colorize(t, [(0, (0.42, 0.22, 0.09)), (0.5, (0.58, 0.33, 0.14)), (1, (0.7, 0.43, 0.2))])
    save_rgb("teak_albedo", rgb)
    save_normal("teak_normal", t * 0.25, 2.0)
    # coal heap
    f1, f2, cid = worley(n, 700, 331)
    dome = np.clip(1 - f1 / 16.0, 0, 1)
    edge = np.clip((f2 - f1) / 5.0, 0, 1)
    shine = np.random.default_rng(332).random(700)[cid]
    t = (0.04 + 0.08 * shine) * (0.4 + 0.6 * edge) + dome ** 6 * 0.08
    rgb = np.stack([t, t, t * 1.05], -1)
    save_rgb("coal_albedo", rgb)
    save_normal("coal_normal", dome * 0.8 + edge * 0.4, 6.0)
    # ribbed rubber cab floor
    ribs = ((np.sin(xx / n * math.pi * 2 * 32) * 0.5 + 0.5) ** 6)
    base = norm01(spectral(n, 1.8, 341))
    t = 0.16 + ribs * 0.05 + base * 0.04
    save_rgb("rubber_albedo", np.stack([t, t, t * 1.04], -1))
    save_normal("rubber_normal", ribs, 4.0)
    # floorboards (A4 footplate)
    plank = 64
    idx = (xx // plank).astype(int)
    tone = np.random.default_rng(351).random(16)[idx % 16]
    grain = norm01(spectral(n, 1.5, 352, aniso=(0.05, 1.0)))
    gaps = (xx % plank) < 2
    wear = norm01(spectral(n, 2.5, 353))
    t = np.clip(0.3 + tone * 0.25 + grain * 0.35, 0, 1)
    rgb = colorize(t, [(0, (0.2, 0.14, 0.09)), (0.5, (0.36, 0.26, 0.17)), (1, (0.5, 0.39, 0.27))])
    rgb = lerp(rgb, np.array([0.3, 0.28, 0.25]), (wear ** 2 * 0.5)[..., None])   # coal dust
    rgb[gaps] *= 0.3
    save_rgb("floorboards_albedo", rgb)
    save_normal("floorboards_normal", grain * 0.3 - gaps.astype(np.float32) * 0.8, 3.0)
    # checker (tread) plate
    cell = 32
    cx = (xx % cell) - cell / 2
    cy = (yy % cell) - cell / 2
    flip = ((xx // cell + yy // cell) % 2) == 0
    u = np.where(flip, cx, cy)
    v = np.where(flip, cy, cx)
    lug = np.clip(1 - (np.abs(u * 0.9 + v * 0.45) / 2.2) ** 2 - (np.abs(v) / 11.0) ** 4, 0, 1)
    base = norm01(spectral(n, 1.8, 361))
    t = 0.36 + base * 0.12 + lug * 0.12
    save_rgb("treadplate_albedo", np.stack([t, t, t * 1.02], -1))
    save_normal("treadplate_normal", lug, 6.0)
    # painted cab metal (multiply): chips and scuffs
    base = 1.0 - norm01(spectral(n, 2.0, 371)) ** 3 * 0.12
    scratches = np.zeros((n, n), np.float32)
    r = np.random.default_rng(372)
    for _ in range(140):
        x, y = r.random() * n, r.random() * n
        a = r.uniform(0, math.pi)
        L = r.uniform(8, 50)
        cv2.line(scratches, (int(x), int(y)), (int(x + math.cos(a) * L), int(y + math.sin(a) * L)), 1.0, 1, cv2.LINE_AA)
    save_gray("paint_wear", np.clip(base - scratches * 0.12, 0, 1))
    # brick (station building)
    bw, bh = 64, 22
    row = (yy // bh).astype(int)
    off = np.where(row % 2 == 0, 0, bw // 2)
    bx = ((xx + off) // bw).astype(int)
    mortar = ((yy % bh) < 3) | (((xx + off) % bw) < 3)
    tone = np.random.default_rng(381).random(4096)[(bx + row * 37) % 4096]
    base = norm01(spectral(n, 1.6, 382))
    t = np.clip(tone * 0.6 + base * 0.4, 0, 1)
    rgb = colorize(t, [(0, (0.36, 0.16, 0.1)), (0.5, (0.52, 0.24, 0.15)), (1, (0.62, 0.36, 0.24))])
    rgb[mortar] = np.array([0.62, 0.6, 0.55]) * (0.85 + 0.15 * base[mortar])[..., None]
    save_rgb("brick_albedo", rgb)
    save_normal("brick_normal", base * 0.2 - mortar.astype(np.float32) * 0.6, 3.0)
    # corrugated iron roofing
    corr = np.sin(xx / n * math.pi * 2 * 16) * 0.5 + 0.5
    rust = norm01(spectral(n, 2.0, 391)) ** 3
    t = 0.55 + norm01(spectral(n, 1.6, 392)) * 0.1
    rgb = np.stack([t, t * 1.01, t * 1.03], -1)
    rgb = lerp(rgb, np.array([0.45, 0.25, 0.14]), (rust * 0.6)[..., None])
    save_rgb("roofiron_albedo", rgb)
    save_normal("roofiron_normal", corr, 6.0)


# --------------------------------------------------------------------- environment
def make_environment():
    print("environment")
    n = 512
    # clouds: R = billows (low freq), G = detail
    c1 = norm01(spectral(n, 3.0, 401))
    c2 = norm01(spectral(n, 1.8, 402, fmin=6))
    c3 = norm01(spectral(n, 2.4, 403))
    save_rgb("clouds", np.stack([c1, c2, c3], -1), jpg=False)
    # water normals: crossing wave trains + chop
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    h = np.zeros((n, n), np.float32)
    r = np.random.default_rng(411)
    for k in range(10):
        kx, ky = r.integers(-9, 10), r.integers(-9, 10)
        if kx == 0 and ky == 0:
            continue
        h += np.sin((xx * kx + yy * ky) * math.pi * 2 + r.uniform(0, 6.28)) / math.hypot(kx, ky)
    h += spectral(n, 2.2, 412, fmin=4) * 0.25
    save_normal("water_normal", h * 0.6, 3.0)
    # smoke / steam puff (RGBA)
    m = 256
    yy, xx = np.mgrid[0:m, 0:m].astype(np.float32)
    d = np.sqrt((xx - m / 2) ** 2 + (yy - m / 2) ** 2) / (m / 2)
    nz = norm01(spectral(m, 2.0, 421)) * 0.6 + norm01(spectral(m, 1.4, 422, fmin=8)) * 0.4
    a = np.clip((1 - d) * 1.6 - (1 - nz) * 0.8, 0, 1) ** 1.4
    shade = 0.75 + 0.25 * nz - 0.2 * (yy / m)        # lit from above
    save_rgba("smoke_puff", np.stack([shade, shade, shade, a], -1))
    # glowing firebed (emission intensity)
    n = 512
    f1, f2, cid = worley(n, 500, 431)
    lump = np.random.default_rng(432).random(500)[cid]
    cracks = np.clip(1 - (f2 - f1) / 7.0, 0, 1) ** 2
    t = np.clip(cracks * 0.9 + lump * 0.25 + norm01(spectral(n, 1.8, 433)) * 0.25, 0, 1)
    save_gray("firebed", t)


# ------------------------------------------------------------------------- scenery
def make_scenery():
    print("scenery")
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # tactile ground surface indicators (yellow studded pavers), 0.6 m square
    sp = n / 12.0
    cx = (xx % sp) - sp / 2
    cy = (yy % sp) - sp / 2
    d = np.sqrt(cx * cx + cy * cy)
    dome = np.clip(1 - (d / (sp * 0.32)) ** 4, 0, 1)
    joints = ((xx % (n / 2)) < 2) | ((yy % (n / 2)) < 2)
    base = norm01(spectral(n, 1.8, 501))
    dirt = norm01(spectral(n, 2.4, 502)) ** 2
    rgb = np.zeros((n, n, 3), np.float32) + np.array([0.86, 0.68, 0.08])
    rgb *= (0.9 + 0.1 * base)[..., None]
    rgb = lerp(rgb, np.array([0.45, 0.4, 0.3]), (dirt * 0.35 * (1 - dome))[..., None])
    rgb[joints] *= 0.5
    save_rgb("tactile_albedo", rgb)
    save_normal("tactile_normal", dome * 0.8 - joints.astype(np.float32) * 0.5, 4.0)

    # slate roof: 4 slates across, 8 courses, staggered
    cw, ch = n // 4, n // 8
    row = (yy // ch).astype(int)
    off = np.where(row % 2 == 0, 0, cw // 2)
    col = ((xx + off) // cw).astype(int)
    within = (yy % ch) / ch                      # 0 at top of course, 1 at its bottom edge
    joint = ((xx + off) % cw) < 3
    tone = np.random.default_rng(511).random(4096)[(col * 13 + row * 71) % 4096]
    grain = norm01(spectral(n, 1.2, 512, aniso=(1.0, 0.2)))
    t = np.clip(0.35 + tone * 0.35 + grain * 0.3, 0, 1)
    rgb = colorize(t, [(0, (0.12, 0.13, 0.16)), (0.5, (0.22, 0.23, 0.27)), (1, (0.33, 0.33, 0.36))])
    lichen = norm01(spectral(n, 2.2, 513)) ** 4
    rgb = lerp(rgb, np.array([0.45, 0.47, 0.32]), (lichen * 0.45)[..., None])
    rgb *= (1 - 0.35 * joint.astype(np.float32) - 0.3 * (within > 0.94))[..., None]
    save_rgb("slate_albedo", rgb)
    save_normal("slate_normal", within * 0.8 - joint.astype(np.float32) * 0.6 + grain * 0.1, 3.0)

    # terracotta roof tiles: rolled pan tiles, 6 across, 7 courses
    cw = n / 6.0
    ch = n / 7.0
    row = (yy // ch).astype(int)
    within = (yy % ch) / ch
    roll = np.cos(((xx + np.where(row % 2 == 0, 0, 0)) % cw) / cw * math.pi * 2) * 0.5 + 0.5
    tone = np.random.default_rng(521).random(4096)[((xx // cw).astype(int) * 31 + row * 7) % 4096]
    t = np.clip(0.3 + tone * 0.4 + norm01(spectral(n, 1.8, 522)) * 0.3, 0, 1)
    rgb = colorize(t, [(0, (0.42, 0.16, 0.09)), (0.5, (0.58, 0.25, 0.14)), (1, (0.7, 0.36, 0.22))])
    dirt = norm01(spectral(n, 2.4, 523)) ** 3
    rgb = lerp(rgb, np.array([0.25, 0.2, 0.16]), (dirt * 0.4)[..., None])
    rgb *= (0.75 + 0.25 * roll)[..., None] * (1 - 0.4 * (within > 0.93))[..., None]
    save_rgb("rooftile_albedo", rgb)
    save_normal("rooftile_normal", roll * 0.6 + within * 0.7, 3.0)

    # weatherboards (painted, tint with albedo colour): 8 boards per texture
    bh = n / 8.0
    within = (yy % bh) / bh
    grain = norm01(spectral(n, 1.4, 531, aniso=(0.06, 1.0)))
    peel = norm01(spectral(n, 2.2, 532)) > 0.86
    dirt = norm01(spectral(n, 2.0, 533, aniso=(1.0, 0.3))) ** 3
    t = 0.86 + grain * 0.06 - dirt * 0.18
    t = np.where(peel, 0.55 + grain * 0.15, t)
    t = t * (1 - 0.45 * (within > 0.92))
    save_rgb("weatherboard_albedo", np.stack([t, t * 0.99, t * 0.96], -1))
    save_normal("weatherboard_normal", within * 0.9 + grain * 0.05, 3.0)

    # ashlar stone (limestone), irregular course heights
    rng = np.random.default_rng(541)
    edges = [0]
    while edges[-1] < n:
        edges.append(edges[-1] + int(rng.integers(52, 84)))
    edges[-1] = n
    row = np.searchsorted(np.array(edges), yy.astype(int), side="right") - 1
    rgb = np.zeros((n, n, 3), np.float32)
    h = np.zeros((n, n), np.float32)
    base = norm01(spectral(n, 1.6, 542))
    pit = norm01(spectral(n, 0.8, 543, fmin=60))
    for r_i in range(len(edges) - 1):
        y0, y1 = edges[r_i], edges[r_i + 1]
        x = int(rng.integers(0, 60))
        cuts = []
        while x < n + 200:
            cuts.append(x)
            x += int(rng.integers(90, 200))
        band = (yy >= y0) & (yy < y1)
        xr = xx.astype(int)
        for c_i in range(len(cuts) - 1):
            a, b = cuts[c_i], cuts[c_i + 1]
            m = band & (((xr - a) % n) < (b - a)) & (((xr - a) % n) >= 0)
            tone = rng.random()
            rgb[m] = np.array([0.7, 0.64, 0.52]) * (0.82 + 0.25 * tone)
        jv = np.zeros((n, n), bool)
        for c in cuts:
            jv |= band & ((((xr - c) % n) < 4))
        rgb[jv] = np.array([0.55, 0.53, 0.48])
        h[jv] -= 1.0
        h[band & ((yy - y0) < 4)] -= 1.0
        rgb[band & ((yy - y0) < 4)] = np.array([0.55, 0.53, 0.48])
    rgb *= (0.85 + 0.2 * base - 0.1 * pit)[..., None]
    soot = norm01(spectral(n, 2.4, 544)) ** 3
    rgb = lerp(rgb, np.array([0.3, 0.29, 0.27]), (soot * 0.3)[..., None])
    save_rgb("stone_albedo", rgb)
    save_normal("stone_normal", h * 0.7 + base * 0.2 + pit * 0.1, 3.0)

    # sash window (two over two) with frame, glass reflection and curtains: 256 x 320
    W, H = 256, 320
    img = Image.new("RGB", (W, H))
    px = np.zeros((H, W, 3), np.float32)
    gy = np.linspace(0, 1, H)[:, None]
    sky = np.array([0.42, 0.5, 0.58]) * (1 - gy[..., None] * 0.6) + np.array([0.08, 0.09, 0.1]) * gy[..., None]
    px[:] = sky
    # curtains: soft folds on both sides of each pane column
    cur = np.zeros((H, W), np.float32)
    xs = np.arange(W)[None, :] / W
    fold = np.sin(xs * math.pi * 40) * 0.5 + 0.5
    cur_mask = (xs < 0.27) | (xs > 0.73)
    px = np.where(cur_mask[..., None], lerp(px, np.array([0.62, 0.55, 0.42]) * (0.75 + 0.25 * fold)[..., None], 0.75), px)
    frame = np.zeros((H, W), bool)
    fw = 16
    frame[:fw, :] = True
    frame[-fw:, :] = True
    frame[:, :fw] = True
    frame[:, -fw:] = True
    frame[H // 2 - 7:H // 2 + 7, :] = True          # meeting rail
    frame[:, W // 2 - 4:W // 2 + 4] = True          # glazing bars
    px[frame] = np.array([0.9, 0.89, 0.85])
    shade = np.zeros((H, W), np.float32)
    shade[fw:fw + 5, :] = 1
    shade[:, fw:fw + 4] = 1
    px *= (1 - 0.35 * shade)[..., None]
    sill = np.zeros((H, W), bool)
    save_rgb("window_albedo", px)
    glass = (~frame).astype(np.float32)
    save_gray("window_mask", glass)

    # panelled door (tint with albedo colour)
    W, H = 128, 256
    d = np.full((H, W), 0.82, np.float32)
    for (x0, y0, x1, y1) in [(14, 14, 60, 112), (68, 14, 114, 112), (14, 128, 60, 242), (68, 128, 114, 242)]:
        d[y0:y1, x0:x1] = 0.72
        d[y0:y0 + 3, x0:x1] = 0.6
        d[y0:y1, x0:x0 + 3] = 0.6
        d[y1 - 3:y1, x0:x1] = 0.92
        d[y0:y1, x1 - 3:x1] = 0.92
    d *= 0.94 + 0.06 * norm01(spectral(256, 1.6, 551))[:H, :W]
    d[120:124, 100:110] = 0.25                       # knob
    save_gray("door_albedo", d)

    # palisade fence (RGBA): natural layout x = along, y = down; saved transposed
    W, H = 256, 128
    a = np.zeros((H, W), np.float32)
    for i in range(8):
        x0 = i * 32 + 10
        a[10:, x0:x0 + 12] = 1
        for k in range(12):                          # pointed tops
            if 10 - k >= 0:
                a[10 - k: 11 - k, x0 + k // 2: x0 + 12 - k // 2] = 1
    a[22:28, :] = 1
    a[100:106, :] = 1
    col = np.zeros((H, W, 3), np.float32) + np.array([0.13, 0.15, 0.13])
    rgba = np.concatenate([col, a[..., None]], -1)
    save_rgba("fence_palisade", np.transpose(rgba, (1, 0, 2)))
    # white picket fence
    a = np.zeros((H, W), np.float32)
    for i in range(4):
        x0 = i * 64 + 18
        a[14:, x0:x0 + 26] = 1
        for k in range(14):
            a[14 - k:15 - k, x0 + k: x0 + 26 - k] = 1
    a[40:50, :] = 1
    a[96:106, :] = 1
    col = np.zeros((H, W, 3), np.float32) + np.array([0.88, 0.87, 0.82])
    col *= (0.85 + 0.15 * norm01(spectral(256, 1.8, 561))[:H, :W])[..., None]
    rgba = np.concatenate([col, a[..., None]], -1)
    save_rgba("fence_picket", np.transpose(rgba, (1, 0, 2)))
    # canopy valance (dagger board)
    W, H = 256, 64
    a = np.zeros((H, W), np.float32)
    a[:22, :] = 1
    for i in range(8):
        x0 = i * 32
        for y in range(22, 62):
            hw = int(16 * (1 - (y - 22) / 40.0))
            a[y, x0 + 16 - hw:x0 + 16 + hw] = 1
    col = np.zeros((H, W, 3), np.float32) + 0.9
    rgba = np.concatenate([col, a[..., None]], -1)
    save_rgba("valance", np.transpose(rgba, (1, 0, 2)))
    # boundary fence wire: 4 strands, barbed top strand (natural layout, saved transposed)
    W, H = 128, 128
    a = np.zeros((H, W), np.float32)
    for y in (8, 40, 74, 108):
        a[y:y + 2, :] = 1
    for x in range(4, W, 16):
        for k in range(-3, 4):
            a[np.clip(9 + k, 0, H - 1), x + k] = 1
            a[np.clip(9 - k, 0, H - 1), x + k] = 1
    col = np.zeros((H, W, 3), np.float32) + np.array([0.55, 0.55, 0.53])
    rgba = np.concatenate([col, a[..., None]], -1)
    save_rgba("fence_wire", np.transpose(rgba, (1, 0, 2)))


JOBS = {"terrain": make_terrain, "track": make_track, "vegetation": make_vegetation,
        "vehicle": make_vehicle, "environment": make_environment, "scenery": make_scenery}

if __name__ == "__main__":
    want = sys.argv[1:] or list(JOBS)
    for k in want:
        for name, fn in JOBS.items():
            if name.startswith(k):
                fn()
    print("done")
