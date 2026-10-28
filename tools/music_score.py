#!/usr/bin/env python3
"""The shipped score (Path E1): two seamless loops built from the synthesisers in music_samples.py (the owner picked the B "pluck" and C "march" styles), plus a quiet sea bed.
Usage: tools/music_score.py [outdir=godot/assets/music]   -> peace.ogg (plucked strings, D dorian, 64 s), war.ogg (drone, hand drums, brass swells, 48 s), sea.ogg (24 s). Needs numpy + ffmpeg.
Everything is synthesised here; there is no third-party audio. The loops wrap: the tail (reverb, decaying notes) is mixed onto the head, so there is no click or gap."""
import sys, os, subprocess, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_samples as M
SR = M.SR
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "music")
os.makedirs(out, exist_ok=True)

def loop(x, length):
    """x is `length` seconds + a tail; the tail is added onto the start so the end flows into the beginning"""
    n = int(length * SR); y = x[:n].copy(); tail = x[n:]
    y[:len(tail)] += tail[:n]
    return y

def save(name, x, peak=0.7, q=3):
    x = np.tanh(x * 1.1); x = x / max(1e-6, np.max(np.abs(x))) * peak
    wav = os.path.join(out, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q), os.path.join(out, name + ".ogg")], check=True)
    os.remove(wav)

TAIL = 4.0
# peace: 64 s. Part one is the B sample; part two walks another progression with a lower pattern and sparser, softer plucks
L = 64.0; B = np.zeros(int((L + TAIL) * SR))
scale = [62, 64, 65, 67, 69, 71, 72, 74]
pat = [0, 2, 4, 7, 4, 2, 3, 5, 7, 5, 4, 2]
for k in range(64):
    m = scale[pat[k % len(pat)]] - (12 if (k // 12) % 2 else 0)
    M.put(B, M.pluck(m, 1.6), k * 0.5)
for k in range(4): M.put(B, M.pad(50 + (0, 3, 5, 0)[k], 9.0) * 0.5, k * 8.0)
pat2 = [7, 5, 4, 2, 4, 5, 3, 2, 0, 2, 4, 3]
for k in range(64):
    if k % 3 == 2: continue
    m = scale[pat2[k % len(pat2)]] - (12 if (k // 16) % 2 == 0 else 0)
    M.put(B, M.pluck(m, 1.8) * (0.8 if k % 2 else 1.0), 32.0 + k * 0.5)
for k in range(4): M.put(B, M.pad(50 + (0, 5, 7, 3)[k], 9.0) * 0.5, 32.0 + k * 8.0)
save("peace", loop(M.reverb(B, 0.4), L))

# war: 48 s drone + drums that thicken in the last third + brass swells on a rising line
L = 48.0; C = np.zeros(int((L + TAIL) * SR))
M.put(C, M.pad(36, 36.0) * 1.2, 0); M.put(C, M.pad(36, 20.0) * 1.2, 30.0)
for k in range(96):
    if k % 4 == 0: M.put(C, M.drum(0.5, 70, 10), k * 0.5)
    elif k % 4 == 2: M.put(C, M.drum(0.3, 110, 16) * 0.6, k * 0.5)
    elif k % 8 == 5: M.put(C, M.drum(0.2, 150, 22) * 0.4, k * 0.5)
    if k >= 64 and k % 2 == 1: M.put(C, M.drum(0.15, 190, 30) * 0.3, k * 0.5)
for m, at in ((48, 4), (51, 10), (55, 16), (53, 22), (48, 27), (55, 33), (58, 38), (60, 43)):
    n = int(5.0 * SR); t = np.arange(n) / SR
    saw = sum(((2 * ((M.hz(m) * j * t) % 1) - 1) / j) for j in (1, 2, 3))
    M.put(C, saw * np.minimum(1, t / 1.5) * np.minimum(1, (5 - t) / 1.2) * 0.2, at)
save("war", loop(M.reverb(C, 0.25), L))

# sea: a very quiet bed (band-passed noise with a slow swell), 24 s
L = 24.0; n = int((L + TAIL) * SR); rng = np.random.default_rng(3)
x = rng.uniform(-1, 1, n); k = int(SR / 700); x = np.convolve(x, np.ones(k) / k, mode="same")        # low-pass ~700 Hz
t = np.arange(n) / SR
x *= 0.55 + 0.45 * np.sin(2 * np.pi * t / 8.0 + 0.7) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 5.3))
save("sea", loop(x, L), peak=0.5, q=1)
print("wrote", sorted(os.listdir(out)))
