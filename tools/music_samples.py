#!/usr/bin/env python3
"""Three short generated music samples for the owner to choose a style from (Path E1). No third-party audio: everything is synthesised with numpy.
Usage: tools/music_samples.py [outdir=docs/media/music_samples]   -> A_orrery.ogg, B_pluck.ogg, C_march.ogg (needs ffmpeg for the ogg)"""
import sys, os, subprocess, wave
import numpy as np
SR = 44100
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "docs", "media", "music_samples")
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(7)

def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-d * t)
def tone(m, dur, a=0.01, d=3.0, harm=(1, .5, .25, .12), vib=0.0):
    n = int(dur * SR); t = np.arange(n) / SR; f = hz(m)
    ph = 2 * np.pi * f * t + (vib * np.sin(2 * np.pi * 5 * t) if vib else 0)
    return sum(h * np.sin(ph * (i + 1)) for i, h in enumerate(harm)) * env(n, a, d) / sum(harm)
def pad(m, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    w = sum(np.sin(2 * np.pi * hz(m) * (1 + dc) * t + p) for dc, p in ((0, 0), (0.003, 1.3), (-0.003, 2.1)))
    w += 0.4 * sum(np.sin(2 * np.pi * hz(m) * 2 * (1 + dc) * t + p) for dc, p in ((0, .4), (0.004, 2.0)))
    e = np.minimum(1, t / 1.6) * np.minimum(1, (dur - t) / 2.2)
    return w * e / 4
def pluck(m, dur, decay=0.996):
    n = int(dur * SR); f = hz(m); L = int(SR / f)
    buf = rng.uniform(-1, 1, L); o = np.zeros(n)
    for i in range(n):
        o[i] = buf[i % L]; buf[i % L] = decay * 0.5 * (buf[i % L] + buf[(i + 1) % L])
    return o * 0.6
def drum(dur=0.3, f0=90, d=14):
    n = int(dur * SR); t = np.arange(n) / SR
    return (np.sin(2 * np.pi * (f0 + 60 * np.exp(-30 * t)) * t) * np.exp(-d * t) + 0.25 * rng.uniform(-1, 1, n) * np.exp(-40 * t)) * 0.9
def reverb(x, mix=0.3):
    y = x.copy()
    for d, g in ((0.043, .45), (0.071, .38), (0.113, .3), (0.17, .22), (0.26, .15)):
        k = int(d * SR); y[k:] += g * x[:-k] * mix * 2
    return y
def put(buf, x, at):
    i = int(at * SR); j = min(len(buf), i + len(x))
    if i < len(buf): buf[i:j] += x[:j - i]
def save(name, x):
    x = np.tanh(x * 1.1); x = x / max(1e-6, np.max(np.abs(x))) * 0.8
    fade = int(1.5 * SR); x[-fade:] *= np.linspace(1, 0, fade); x[:int(.6 * SR)] *= np.linspace(0, 1, int(.6 * SR))
    wav = os.path.join(out, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", os.path.join(out, name + ".ogg")], check=True)
    os.remove(wav)

# A: Orrery - slow pads over a bell arpeggio (title / peace)
dur = 32; A = np.zeros(int(dur * SR))
prog = [(45, 52, 57, 60), (41, 48, 53, 57), (48, 55, 60, 64), (43, 50, 55, 59)]
for k in range(4):
    for m in prog[k]: put(A, pad(m, 9.0), k * 8.0)
for k in range(32):
    ch = prog[k // 8]; m = ch[1 + (k * 3) % 3] + 12
    put(A, tone(m, 2.2, 0.004, 3.2, (1, .3, .1)) * 0.35, k * 1.0 + 0.25)
save("A_orrery", reverb(A))

# B: Pluck - a plucked-string arpeggio in D dorian (a chronicle / diplomacy)
dur = 32; B = np.zeros(int(dur * SR))
scale = [62, 64, 65, 67, 69, 71, 72, 74]
pat = [0, 2, 4, 7, 4, 2, 3, 5, 7, 5, 4, 2]
for k in range(64):
    m = scale[pat[k % len(pat)]] - (12 if (k // 12) % 2 else 0)
    put(B, pluck(m, 1.6), k * 0.5)
for k in range(4): put(B, pad(50 + (0, 3, 5, 0)[k], 9.0) * 0.5, k * 8.0)
save("B_pluck", reverb(B, 0.4))

# C: March - a low drone, hand drums and brass-like swells (war / Napoleonic, Mongol)
dur = 32; C = np.zeros(int(dur * SR))
put(C, pad(36, 32.0) * 1.2, 0)
for k in range(64):
    if k % 4 == 0: put(C, drum(0.5, 70, 10), k * 0.5)
    elif k % 4 == 2: put(C, drum(0.3, 110, 16) * 0.6, k * 0.5)
    elif k % 8 == 5: put(C, drum(0.2, 150, 22) * 0.4, k * 0.5)
for k, (m, at) in enumerate(((48, 4), (51, 10), (55, 16), (53, 22), (48, 27))):
    n = int(5.0 * SR); t = np.arange(n) / SR
    saw = sum(((2 * ((hz(m) * j * t) % 1) - 1) / j) for j in (1, 2, 3))
    put(C, saw * np.minimum(1, t / 1.5) * np.minimum(1, (5 - t) / 1.2) * 0.2, at)
save("C_march", reverb(C, 0.25))
print("wrote", os.listdir(out))
