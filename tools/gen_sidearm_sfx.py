"""Generate extra SFX for the sidearms update (pistols and knives)."""
import os
import wave

import numpy as np

SR = 44100
OUT = "/home/ruzik-admin/Документы/Проект по умолчанию/godot_project/assets/audio"


def save(name, data):
    data = np.clip(data, -1.0, 1.0)
    stereo = np.stack([data, data * 0.97], axis=1)
    pcm = (stereo * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("WROTE", name, len(data) / SR)


t = np.arange(SR) / SR
noise = np.random.default_rng(7).normal(0, 1, SR)

# Pistol: sharp transient + short metallic tail.
env = np.exp(-t * 34.0)
body = np.sin(2 * np.pi * (1550 * np.exp(-t * 9.0) + 190) * t) * 0.45
click = np.sin(2 * np.pi * 3100 * t) * np.exp(-t * 95.0) * 0.5
crack = noise * np.exp(-t * 120.0) * 0.35
save("pistol_shot", (body + click + crack) * env * 0.95)

# Knife swing: band-limited whoosh sweeping upward then fading.
dur = 0.34
n = int(SR * dur)
tt = np.arange(n) / SR
rng = np.random.default_rng(19)
nz = rng.normal(0, 1, n)
# simple cumulative moving average = low-pass sweep
win = (9 + 34 * np.sin(np.pi * tt / dur) ** 2).astype(int)
smoothed = np.array([nz[max(0, i - w):i + 1].mean() for i, w in enumerate(win)])
env2 = np.sin(np.pi * tt / dur) ** 1.6
swing = smoothed * env2 * 2.6
save("knife_swing", swing[:int(SR * 0.30)])

# Knife hit: metallic ping over a soft thud.
dur = 0.22
n = int(SR * dur)
tt = np.arange(n) / SR
ping = np.sin(2 * np.pi * 2400 * tt) * np.exp(-tt * 28.0) * 0.42
ping += np.sin(2 * np.pi * 1870 * tt) * np.exp(-tt * 21.0) * 0.25
thud = np.sin(2 * np.pi * 130 * tt) * np.exp(-tt * 24.0) * 0.55
save("knife_hit", ping + thud)

# Pistol reload: two mechanical clicks.
dur = 0.5
n = int(SR * dur)
tt = np.arange(n) / SR
rng = np.random.default_rng(31)
clicks = np.zeros(n)
for center, amp in ((0.06, 0.7), (0.22, 0.55), (0.36, 0.8)):
    idx = int(center * SR)
    seg = rng.normal(0, 1, 2600) * np.exp(-np.arange(2600) / 380.0)
    tone = np.sin(2 * np.pi * 1450 * np.arange(2600) / SR) * np.exp(-np.arange(2600) / 260.0)
    clicks[idx:idx + 2600] += (seg * 0.5 + tone * 0.5) * amp
save("pistol_reload", clicks)
