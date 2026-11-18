"""Generate textures, effect sprites, UI vignettes and all audio for RUBEZH.

Run:  python3 tools/gen_assets.py
Everything is original and generated locally.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, 'godot_project/assets/textures')
AUD = os.path.join(ROOT, 'godot_project/assets/audio')
os.makedirs(TEX, exist_ok=True)
os.makedirs(AUD, exist_ok=True)

SR = 44100
rng = np.random.default_rng(20261118)


# ===================================================================== textures
def periodic_noise(size, scale, seed, octaves=5, decay=0.55):
    r = np.random.default_rng(seed)
    xs = np.linspace(0.0, 1.0, size, endpoint=False)
    X, Y = np.meshgrid(xs, xs)
    total = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        freq = max(1.0, scale * (2 ** o))
        for _ in range(7):
            theta = r.uniform(0, 2 * math.pi)
            fx = int(round(freq * math.cos(theta)))
            fy = int(round(freq * math.sin(theta)))
            if fx == 0 and fy == 0:
                continue
            phase = r.uniform(0, 2 * math.pi)
            total += amp * np.sin(2 * math.pi * (fx * X + fy * Y) + phase)
        amp *= decay
    total -= total.min()
    if total.max() > 0:
        total /= total.max()
    return total


def to_img(arr, mode='L'):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)


def save(img, name):
    path = os.path.join(TEX, name)
    img.save(path, optimize=True)
    print('TEX', name, img.size)


def grunge_lines(size, seed, count=18, color=(30, 28, 26), alpha=70, length=(40, 220)):
    r = np.random.default_rng(seed)
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x = r.integers(0, size)
        y = r.integers(0, size)
        ang = r.uniform(0, math.pi * 2)
        ln = r.integers(*length)
        pts = []
        for s in range(8):
            a = ang + r.uniform(-0.5, 0.5)
            x += math.cos(a) * ln / 8
            y += math.sin(a) * ln / 8
            pts.append((x % size, y % size))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.line([(px + ox, py + oy) for px, py in pts], fill=(*color, int(alpha)),
                       width=int(r.integers(1, 3)))
    return layer


def make_concrete_floor(size=1024):
    n = periodic_noise(size, 3, 11, 6)
    fine = periodic_noise(size, 48, 12, 2)
    base = 66 + n * 26 + (fine - 0.5) * 14
    stain = periodic_noise(size, 2, 13, 3)
    stain = np.clip((stain - 0.48) * 2.4, 0, 1)
    base = base * (1.0 - 0.28 * stain)
    rgb = np.dstack([base * 1.00, base * 1.00, base * 0.98])
    img = to_img(rgb, 'RGB')
    img = Image.alpha_composite(img.convert('RGBA'), grunge_lines(size, 14, 26, (24, 22, 20), 90))
    # dark cracks
    img = Image.alpha_composite(img, grunge_lines(size, 15, 9, (18, 17, 16), 160, (60, 300)))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(16)
    for _ in range(1800):
        x, y = r.integers(0, size, 2)
        v = int(r.integers(30, 100))
        d.point((x, y), fill=(v, v, v - 2, 120))
    # faded yellow walkway line near the edge
    d.rectangle([0, 0, size, 18], fill=(150, 116, 34, 90))
    d.rectangle([0, 26, size, 30], fill=(20, 20, 20, 60))
    return img.convert('RGB')


def make_concrete_wall(size=1024):
    n = periodic_noise(size, 4, 21, 6)
    streak = periodic_noise(size, 3, 22, 4)
    # vertical streaks
    streak = np.repeat(streak[:1, :], size, axis=0) * 0.35 + np.repeat(streak.mean(axis=1)[:, None], size, axis=1) * 0.65
    base = 82 + n * 22 - streak * 18
    stain = periodic_noise(size, 2, 23, 3)
    base *= (1.0 - 0.22 * np.clip((stain - 0.5) * 3, 0, 1))
    rgb = np.dstack([base, base * 0.995, base * 0.97])
    img = to_img(rgb, 'RGB').convert('RGBA')
    img = Image.alpha_composite(img, grunge_lines(size, 24, 14, (26, 24, 22), 55))
    d = ImageDraw.Draw(img)
    # formwork seams and tie holes
    for y in (0, size // 2):
        d.rectangle([0, y - 2, size, y + 1], fill=(38, 38, 36, 170))
    for x in range(0, size, size // 4):
        for y in (size // 4, 3 * size // 4):
            d.ellipse([x + 26, y - 7, x + 40, y + 7], fill=(40, 38, 35, 180))
    return img.convert('RGB')


def make_metal(size=1024):
    brushed = periodic_noise(size, 30, 31, 3)
    brushed = np.repeat(brushed.mean(axis=0)[None, :], size, axis=0) * 0.5 + brushed * 0.5
    base = 42 + brushed * 26
    rustmask = periodic_noise(size, 3, 32, 4)
    rustmask = np.clip((rustmask - 0.58) * 2.6, 0, 1)
    rust = np.dstack([110 + brushed * 30, 56 + brushed * 16, 28 + brushed * 10])
    rgb = np.dstack([base * 0.92, base * 0.98, base * 1.06])
    rgb = rgb * (1 - rustmask[..., None]) + rust * rustmask[..., None]
    img = to_img(rgb, 'RGB').convert('RGBA')
    img = Image.alpha_composite(img, grunge_lines(size, 33, 30, (185, 187, 190), 40, (10, 120)))
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x, y = rng.integers(0, size, 2)
        ln = int(rng.integers(8, 60))
        d.line([(x, y), (x + ln, y + int(rng.integers(-2, 3)))], fill=(150, 152, 158, 70), width=1)
    return img.convert('RGB')


def make_wood(size=1024):
    grain = periodic_noise(size, 46, 41, 3)
    grain = np.repeat(grain[:, :1], size, axis=1) * 0.55 + grain * 0.45
    plank = np.zeros((size, size))
    for x in range(0, size, size // 6):
        plank[:, x:x + size // 6] = (x // (size // 6)) % 2
    base = 96 + grain * 44 - plank * 8
    rgb = np.dstack([base * 1.05, base * 0.72, base * 0.42])
    img = to_img(rgb, 'RGB').convert('RGBA')
    d = ImageDraw.Draw(img)
    for x in range(0, size, size // 6):
        d.rectangle([x - 2, 0, x + 2, size], fill=(34, 22, 12, 220))
    r = np.random.default_rng(42)
    for _ in range(160):
        x, y = r.integers(0, size, 2)
        d.ellipse([x, y, x + int(r.integers(2, 6)), y + int(r.integers(2, 4))], fill=(48, 30, 16, 130))
    return img.convert('RGB')


def make_hazard(size=512):
    img = Image.new('RGB', (size, size), (24, 23, 20))
    d = ImageDraw.Draw(img)
    band = size // 5
    for i in range(-size, size * 2, band * 2):
        d.polygon([(i, 0), (i + band, 0), (i + band + size, size), (i + size, size)],
                  fill=(208, 148, 28))
    gr = to_img(periodic_noise(size, 6, 51, 5) * 255).convert('RGBA')
    gr.putalpha(70)
    img = Image.alpha_composite(img.convert('RGBA'), gr)
    # scratches
    img = Image.alpha_composite(img, grunge_lines(size, 52, 30, (35, 30, 20), 120, (10, 100)))
    return img.convert('RGB')


def make_detail(size=512, kind='concrete'):
    if kind == 'wood':
        n = periodic_noise(size, 42, 61, 4)
        n = np.repeat(n[:, :1], size, axis=1) * 0.35 + n * 0.65
        v = 150 + n * 105
    elif kind == 'metal':
        n = periodic_noise(size, 36, 62, 4)
        v = 130 + n * 125
        streaks = periodic_noise(size, 30, 63, 2)
        v *= 0.85 + 0.3 * np.repeat(streaks.mean(axis=0)[None, :], size, axis=0)
    elif kind == 'sand':
        n = periodic_noise(size, 70, 64, 3)
        weave = (np.sin(np.arange(size) * 3.4)[:, None] * 0.5 + 0.5) * 24
        v = 160 + n * 80 + weave
    elif kind == 'plate':
        n = periodic_noise(size, 5, 65, 5)
        v = 175 + n * 70
    else:
        n = periodic_noise(size, 22, 66, 5)
        v = 155 + n * 90
    return to_img(np.clip(v, 0, 255), 'L').convert('RGB')


def save_rgba(size, pixels, name):
    img = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    save(img, name)


def radial(size, power=2.0, color=(255, 255, 255), inner=0.0):
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (size / 2)
    a = np.clip((1 - r) / max(1e-4, 1 - inner), 0, 1) ** power
    out = np.zeros((size, size, 4))
    out[..., 0] = color[0]
    out[..., 1] = color[1]
    out[..., 2] = color[2]
    out[..., 3] = a * 255
    return out


def make_flash(size=256):
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx, dy = (x - cx) / (size / 2), (y - cy) / (size / 2)
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    star = np.abs(np.cos(ang * 3)) ** 12 * np.clip(1 - r, 0, 1) ** 1.4
    core = np.clip(1 - r * 2.2, 0, 1) ** 2.2
    a = np.clip(star * 1.2 + core * 1.4, 0, 1)
    out = np.zeros((size, size, 4))
    out[..., 0] = 255
    out[..., 1] = 210 - 40 * (1 - core)[..., None].squeeze() * 0
    out[..., 1] = 225
    out[..., 2] = 170
    out[..., 3] = a * 255
    return out


def make_smoke(size=128):
    n = periodic_noise(size, 3, 71, 4)
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 1.6 * (0.55 + 0.45 * n)
    out = np.zeros((size, size, 4))
    out[..., :3] = 235
    out[..., 3] = a * 190
    return out


def make_bullet_hole(size=128):
    out = np.zeros((size, size, 4))
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (size / 2)
    out[..., 0] = 22
    out[..., 1] = 20
    out[..., 2] = 18
    out[..., 3] = np.clip(1 - r, 0, 1) ** 3 * 245
    img = Image.fromarray(out.astype(np.uint8), 'RGBA')
    d = ImageDraw.Draw(img)
    rng2 = np.random.default_rng(81)
    for _ in range(9):
        a = rng2.uniform(0, 2 * math.pi)
        ln = rng2.uniform(10, 46)
        d.line([(cx, cy), (cx + math.cos(a) * ln, cy + math.sin(a) * ln)],
               fill=(38, 36, 33, int(rng2.integers(90, 180))), width=1)
    return np.array(img)


def make_vignette(size=512, color=(0, 0, 0), strength=255):
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx, dy = (x - cx) / (size / 2), (y - cy) / (size / 2)
    r = np.sqrt(dx * dx + dy * dy) / 1.414
    a = np.clip((r - 0.28) / 0.72, 0, 1) ** 1.8 * strength
    out = np.zeros((size, size, 4))
    out[..., 0], out[..., 1], out[..., 2] = color
    out[..., 3] = a
    return out


save(make_concrete_floor(), 'concrete_floor.png')
save(make_concrete_wall(), 'concrete_wall.png')
save(make_metal(), 'metal_plate.png')
save(make_wood(), 'wood_planks.png')
save(make_hazard(), 'hazard_stripes.png')
for k in ('concrete', 'metal', 'wood', 'sand', 'plate'):
    save(make_detail(kind=k), f'detail_{k}.png')
save_rgba(256, make_flash(), 'fx_flash.png')
save_rgba(64, radial(64, 2.4, (255, 210, 150)), 'fx_spark.png')
save_rgba(128, make_smoke(), 'fx_smoke.png')
save_rgba(128, make_bullet_hole(), 'fx_bullet_hole.png')
save_rgba(512, make_vignette(512, (0, 0, 0), 255), 'ui_vignette.png')
save_rgba(512, make_vignette(512, (180, 12, 8), 255), 'ui_vignette_red.png')
save_rgba(128, radial(128, 2.0, (255, 170, 70), 0.1), 'fx_glow.png')
save_rgba(64, radial(64, 1.5, (255, 255, 255)), 'fx_dot.png')

# scanning line / grain for UI
scan = np.zeros((512, 512, 4))
scan[::4, :, 3] = 22
scan[..., :3] = 255
save_rgba(512, scan, 'ui_scanlines.png')


# ======================================================================= audio
def T(dur):
    return np.arange(int(dur * SR)) / SR


def norm(x, peak=0.92):
    m = np.max(np.abs(x)) if len(x) else 0
    if m > 1e-9:
        x = x / m * peak
    return x


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * T(dur) + phase)


def sweep(f0, f1, dur, kind='sine'):
    t = T(dur)
    freq = f0 * (f1 / f0) ** (t / max(dur, 1e-6))
    ph = 2 * np.pi * np.cumsum(freq) / SR
    if kind == 'saw':
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == 'square':
        return np.sign(np.sin(ph))
    return np.sin(ph)


def env(dur, attack=0.004, decay=None, power=2.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    if decay is None:
        decay = dur
    d = np.exp(-t / max(decay, 1e-5)) ** power
    return a * d


def noise(dur, seed=0):
    r = np.random.default_rng(seed)
    return r.standard_normal(int(dur * SR))


def fft_filter(x, lo=None, hi=None, slope=2.0):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(f)
    if lo:
        mask *= 1 / (1 + (lo / np.maximum(f, 1e-6)) ** (2 * slope))
    if hi:
        mask *= 1 / (1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * mask, n)


def add(buf, start, sig, gain=1.0, wrap=True):
    n = len(buf)
    i0 = int(start * SR)
    idx = (np.arange(len(sig)) + i0) % n if wrap else np.arange(len(sig)) + i0
    if wrap:
        np.add.at(buf, idx, sig * gain)
    else:
        valid = idx < n
        np.add.at(buf, idx[valid], (sig * gain)[valid])


def click(freq=1800, dur=0.05, seed=0, tone=1.0):
    t = T(dur)
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t * 90)
    nz = fft_filter(noise(dur, seed), 1500, 9000) * np.exp(-t * 160) * 0.7
    return norm(body * tone + nz, 0.8)


def metal_hit(dur=0.14, base=1200, seed=0):
    t = T(dur)
    x = np.zeros_like(t)
    for f, a, d in ((base, 0.6, 26), (base * 1.51, 0.35, 35), (base * 2.31, 0.2, 50)):
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * d)
    x += fft_filter(noise(dur, seed), 800, 8000) * np.exp(-t * 70) * 0.6
    return norm(x, 0.8)


def make_sfx():
    sfx = {}
    # --- AK shots: three variations
    for i in range(3):
        dur = 0.55 + i * 0.04
        t = T(dur)
        body = np.sin(2 * np.pi * (95 * np.exp(-t * 7) + 48) * t) * np.exp(-t * 7) * 1.1
        nz = fft_filter(noise(dur, 100 + i), 90 - i * 10, 8000 - i * 700, 1.2)
        nz *= np.exp(-t * (15 - i * 2))
        crack = fft_filter(noise(dur, 110 + i), 2200, 12000) * np.exp(-t * 110) * 0.8
        tail = fft_filter(noise(dur, 120 + i), 200, 2400) * np.exp(-t * 5.5) * 0.35
        x = body + nz * 0.9 + crack + tail
        x = np.tanh(x * 1.7) * 0.85
        sfx[f'shot_{i + 1}'] = norm(x, 0.95)
    # --- empty / bolt
    sfx['empty'] = click(2400, 0.07, 130, 0.8)
    # reload stages
    def mech(dur=0.4, seed=0, thump=90, clicks=()):
        t = T(dur)
        x = fft_filter(noise(dur, seed), 300, 6000) * np.exp(-t * 25) * 0.25
        x += np.sin(2 * np.pi * thump * t) * np.exp(-t * 30) * 0.4
        for ct, cf in clicks:
            c = click(cf, min(0.09, dur - ct), seed + int(ct * 100))
            add(x, ct, c, 0.8, wrap=False)
        return norm(x, 0.8)
    sfx['reload_out'] = mech(0.42, 140, 120, ((0.05, 1700), (0.24, 1100)))
    sfx['reload_in'] = mech(0.46, 141, 95, ((0.10, 900), (0.30, 1400)))
    sfx['reload_bolt'] = mech(0.5, 142, 140, ((0.06, 2000), (0.34, 2600)))
    # --- footsteps
    for i in range(4):
        t = T(0.22)
        nz = fft_filter(noise(0.22, 150 + i), 40, 500) * np.exp(-t * 22)
        thump = np.sin(2 * np.pi * (70 + i * 6) * t) * np.exp(-t * 34) * 0.5
        grit = fft_filter(noise(0.22, 160 + i), 1200, 4000) * np.exp(-t * 65) * 0.15
        sfx[f'step_{i + 1}'] = norm(nz + thump + grit, 0.55)
    # jump / land
    t = T(0.32)
    sfx['jump'] = norm(fft_filter(noise(0.32, 170), 300, 2000) * np.exp(-t * 12) * 0.5
                       + np.sin(2 * np.pi * (180 + 260 * t) * t) * np.exp(-t * 8) * 0.2, 0.5)
    t = T(0.3)
    sfx['land'] = norm(np.sin(2 * np.pi * 62 * t) * np.exp(-t * 18)
                       + fft_filter(noise(0.3, 171), 40, 700) * np.exp(-t * 22) * 0.6, 0.65)
    # hurt
    t = T(0.4)
    sfx['hurt'] = norm(np.sin(2 * np.pi * (160 - 100 * t) * t) * np.exp(-t * 10) * 0.6
                       + fft_filter(noise(0.4, 180), 100, 1200) * np.exp(-t * 14) * 0.5, 0.7)
    # --- impacts
    for name, lo, hi, dur in (('impact_concrete', 120, 2500, 0.16),
                              ('impact_metal', 900, 9000, 0.13)):
        t = T(dur)
        x = fft_filter(noise(dur, 190), lo, hi) * np.exp(-t * 55)
        x += np.sin(2 * np.pi * (1800 if name == 'impact_metal' else 220) * t) * np.exp(-t * 40) * 0.25
        sfx[name] = norm(x, 0.55)
    sfx['hitmarker'] = norm(metal_hit(0.09, 2300, 191), 0.55)
    # headshot ding
    t = T(0.6)
    ding = (np.sin(2 * np.pi * 2637 * t) + 0.6 * np.sin(2 * np.pi * 3951 * t)) * np.exp(-t * 8)
    sfx['headshot'] = norm(ding, 0.6)
    # --- enemy
    sfx['enemy_shot'] = norm(sweep(1200, 220, 0.28, 'saw') * env(0.28, 0.002, 0.09, 1.6) * 0.7
                             + fft_filter(noise(0.28, 200), 600, 6000) * env(0.28, 0.002, 0.06) * 0.25, 0.7)
    sfx['enemy_charge'] = norm(sweep(220, 880, 0.48) * env(0.48, 0.2, 0.4, 1.2) * 0.5
                               + np.sin(2 * np.pi * 55 * T(0.48)) * env(0.48, 0.1, 0.3) * 0.3, 0.55)
    sfx['enemy_hit'] = metal_hit(0.12, 950, 201)
    t = T(0.75)
    sfx['enemy_death'] = norm(sweep(420, 40, 0.75, 'saw') * np.exp(-t * 3.2) * 0.7
                              + fft_filter(noise(0.75, 202), 100, 5000) * np.exp(-t * 6) * 0.5
                              + np.sin(2 * np.pi * 45 * t) * np.exp(-t * 4) * 0.5, 0.85)
    sfx['boss_roar'] = norm(sweep(85, 38, 1.6, 'saw') * env(1.6, 0.12, 0.9, 1.4) * 0.8
                            + fft_filter(noise(1.6, 203), 30, 900) * env(1.6, 0.1, 0.8) * 0.6, 0.9)
    sfx['summon'] = norm(sweep(160, 640, 1.0, 'square') * env(1.0, 0.3, 0.9) * 0.35
                         + sweep(240, 960, 1.0) * env(1.0, 0.4, 0.9) * 0.3, 0.6)
    # explosion
    t = T(1.6)
    sfx['explosion'] = norm(fft_filter(noise(1.6, 210), 25, 3500, 1.0) * np.exp(-t * 3.2) * 1.0
                            + np.sin(2 * np.pi * (55 * np.exp(-t * 2) + 28) * t) * np.exp(-t * 3.5) * 0.9
                            + fft_filter(noise(1.6, 211), 2000, 10000) * np.exp(-t * 22) * 0.4, 0.95)
    # --- pickups / ui
    def blip(f0, f1, dur=0.18, gain=0.5):
        return norm(sweep(f0, f1, dur) * env(dur, 0.003, 0.08, 1.5) * gain, 0.55)
    sfx['pickup_ammo'] = blip(520, 880, 0.2, 0.6)
    sfx['pickup_med'] = blip(660, 990, 0.26, 0.6)
    sfx['ui_click'] = norm(click(3200, 0.05, 220, 0.5) + click(1600, 0.05, 221, 0.3), 0.35)
    sfx['ui_hover'] = norm(click(4200, 0.035, 222, 0.4), 0.18)
    # wave siren
    dur = 2.6
    t = T(dur)
    tone = np.sign(np.sin(2 * np.pi * 2.0 * t)) * 0.5 + 0.5
    sig = np.sin(2 * np.pi * (330 + 180 * tone) * t) * 0.5
    sig += fft_filter(noise(dur, 230), 100, 900) * 0.1
    sfx['wave_start'] = norm(sig * env(dur, 0.15, 2.4, 0.6), 0.55)
    sfx['wave_clear'] = norm((sine(523, 0.7) * 0.4 + sine(659, 0.7) * 0.4 + sine(784, 0.7) * 0.4)
                             * env(0.7, 0.02, 0.45, 1.4), 0.6)
    # victory fanfare
    def fanfare(notes, step=0.28, dur=0.8):
        out = np.zeros(int((step * (len(notes) - 1) + dur) * SR))
        for i, f in enumerate(notes):
            sig = (sine(f, dur) * 0.5 + sine(f * 2, dur) * 0.22 + sine(f * 3, dur) * 0.1)
            sig *= env(dur, 0.01, 0.5, 1.3)
            add(out, i * step, sig, 0.7, wrap=False)
        return norm(out, 0.7)
    sfx['victory'] = fanfare([392, 523.25, 659.25, 783.99])
    sfx['defeat'] = fanfare([220, 174.61, 146.83, 110], 0.36, 1.4)
    return sfx


def write_wav(name, x, stereo_width=0.0):
    x = np.nan_to_num(x)
    if x.ndim == 1:
        if stereo_width > 0:
            d = int(0.0004 * SR)
            left = x
            right = np.concatenate([np.zeros(d), x[:-d]]) * 0.96
            data = np.stack([left, right], axis=1)
        else:
            data = np.stack([x, x], axis=1)
    else:
        data = x
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype('<i2')
    path = os.path.join(AUD, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('WAV', name, f'{len(data) / SR:.2f}s', os.path.getsize(path) // 1024, 'KB')


def midi_freq(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def synth_note(buf, start, dur, freq, gain=0.2, kind='saw', attack=0.005, decay=0.35, cutoff=2400):
    t = T(dur)
    if kind == 'saw':
        sig = 2 * ((freq * t) % 1) - 1
    elif kind == 'square':
        sig = np.sign(np.sin(2 * np.pi * freq * t))
    elif kind == 'tri':
        sig = 2 * np.abs(2 * ((freq * t) % 1) - 1) - 1
    else:
        sig = np.sin(2 * np.pi * freq * t)
    sig *= env(dur, attack, decay, 1.4)
    if kind in ('saw', 'square'):
        sig = fft_filter(sig, 40, cutoff, 2.0)
    add(buf, start, sig, gain)


def make_music_menu(dur=40.0):
    bpm = 76
    beat = 60 / bpm
    n = int(dur * SR)
    buf = np.zeros(n)
    chords = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]
    bar = beat * 4
    for i in range(int(dur / bar) + 1):
        root, notes = chords[i % 4]
        st = i * bar
        synth_note(buf, st, bar * 1.02, midi_freq(root - 12), 0.20, 'sine', 0.8, 1.6, 400)
        for j, m in enumerate(notes):
            synth_note(buf, st + j * 0.02, bar * 1.02, midi_freq(m), 0.055, 'saw', 1.2, 1.8, 900)
        # sparse bell
        if i % 2 == 0:
            synth_note(buf, st + beat * 2, 1.8, midi_freq(notes[2] + 12), 0.07, 'sine', 0.005, 0.9, 8000)
    # heartbeat sub
    for i in range(int(dur / (beat * 2))):
        t0 = i * beat * 2
        add(buf, t0, np.sin(2 * np.pi * 42 * T(0.7)) * env(0.7, 0.02, 0.25, 2), 0.18)
    # air noise
    nz = fft_filter(noise(dur, 300), 200, 1400) * 0.035
    buf += nz
    # wrap fade
    f = int(0.4 * SR)
    buf[:f] *= np.linspace(0, 1, f)
    buf[-f:] *= np.linspace(1, 0, f)
    return norm(buf, 0.55)


def make_music_combat(dur=32.0):
    bpm = 128
    beat = 60 / bpm
    n = int(dur * SR)
    buf = np.zeros(n)
    bars = int(dur / (beat * 4))
    roots = [45, 45, 41, 43, 45, 45, 48, 43]  # A A F G...
    scale = [0, 3, 5, 7, 10]  # minor pentatonic
    for b in range(bars):
        st = b * beat * 4
        root = roots[b % len(roots)]
        # kick 4-on-floor + extra syncopation
        for k in range(4):
            t0 = st + k * beat
            add(buf, t0, np.sin(2 * np.pi * (52 * np.exp(-T(0.35) * 9) + 38) * T(0.35))
                * env(0.35, 0.002, 0.10, 1.6), 0.55)
        if b % 2 == 1:
            add(buf, st + beat * 2.5, np.sin(2 * np.pi * 50 * T(0.3)) * env(0.3, 0.002, 0.09, 1.6), 0.3)
        # snare on 2 and 4
        for k in (1, 3):
            t0 = st + k * beat
            sn = fft_filter(noise(0.24, 310 + b * 4 + k), 150, 5200) * env(0.24, 0.002, 0.10, 1.4)
            add(buf, t0, sn, 0.24)
        # hats 8ths
        for k in range(8):
            t0 = st + k * beat / 2
            h = fft_filter(noise(0.07, 330 + b * 8 + k), 6000, 14000) * env(0.07, 0.001, 0.02)
            add(buf, t0, h, 0.055 if k % 2 else 0.085)
        # driving bass 8ths with octave accents
        for k in range(8):
            m = root + (12 if k % 4 == 3 else 0) - (0 if k % 2 == 0 else 0)
            synth_note(buf, st + k * beat / 2, beat * 0.46, midi_freq(m), 0.16, 'saw', 0.004, 0.14, 420)
        # arp 16ths, second half of loop only
        if b % 2 == 0:
            base = root + 24
            seq = [0, 7, 12, 7, 3, 10, 12, 10]
            for k in range(8):
                t0 = st + k * beat / 2
                synth_note(buf, t0, beat * 0.45, midi_freq(base + seq[k]), 0.035, 'square', 0.003, 0.1, 2600)
        # stabs every 4 bars
        if b % 4 == 3:
            for m in (root + 12, root + 19, root + 24):
                synth_note(buf, st + beat * 3.0, beat * 0.9, midi_freq(m), 0.06, 'saw', 0.02, 0.35, 1600)
    f = int(0.12 * SR)
    buf[:f] *= np.linspace(0, 1, f)
    buf[-f:] *= np.linspace(1, 0, f)
    return norm(buf, 0.62)


def make_music_boss(dur=32.0):
    bpm = 142
    beat = 60 / bpm
    n = int(dur * SR)
    buf = np.zeros(n)
    bars = int(dur / (beat * 4))
    roots = [38, 38, 37, 39]
    for b in range(bars):
        st = b * beat * 4
        root = roots[(b // 2) % 4]
        # double kick
        for k in range(8):
            t0 = st + k * beat / 2
            add(buf, t0, np.sin(2 * np.pi * (58 * np.exp(-T(0.3) * 10) + 36) * T(0.3))
                * env(0.3, 0.001, 0.08, 1.8), 0.5 if k % 2 == 0 else 0.32)
        # industrial snare
        for k in (1, 3):
            sn = fft_filter(noise(0.3, 410 + b * 3 + k), 120, 6000) * env(0.3, 0.001, 0.11, 1.3)
            add(buf, st + k * beat, sn, 0.3)
            add(buf, st + k * beat, np.sin(2 * np.pi * 180 * T(0.12)) * env(0.12, 0.001, 0.04), 0.1)
        # 16th hats
        for k in range(16):
            h = fft_filter(noise(0.05, 430 + b * 16 + k), 7000, 15000) * env(0.05, 0.001, 0.012)
            add(buf, st + k * beat / 4, h, 0.035 + 0.02 * (k % 4 == 2))
        # bass gallop
        for k in range(8):
            m = root - 12 + (3 if k % 4 == 2 else 0)
            synth_note(buf, st + k * beat / 2, beat * 0.4, midi_freq(m), 0.2, 'saw', 0.003, 0.1, 350)
        # dissonant brass
        if b % 2 == 0:
            for m in (root, root + 6, root + 11):
                synth_note(buf, st, beat * 3.6, midi_freq(m + 12), 0.04, 'saw', 0.15, 1.4, 1200)
        # alarm arp
        for k in range(4):
            m = root + 24 + (0, 6, 12, 6)[k]
            synth_note(buf, st + k * beat, beat * 0.8, midi_freq(m), 0.05, 'square', 0.004, 0.28, 3000)
    f = int(0.12 * SR)
    buf[:f] *= np.linspace(0, 1, f)
    buf[-f:] *= np.linspace(1, 0, f)
    return norm(buf, 0.65)


def main():
    sfx = make_sfx()
    for name, sig in sfx.items():
        write_wav(name, norm(sig, 0.9), stereo_width=0.3 if name not in ('ui_click', 'ui_hover') else 0)
    write_wav('music_menu', make_music_menu(), 0.0)
    write_wav('music_combat', make_music_combat(), 0.0)
    write_wav('music_boss', make_music_boss(), 0.0)
    print('AUDIO DONE', len(sfx) + 3, 'files')


if __name__ == '__main__':
    main()
