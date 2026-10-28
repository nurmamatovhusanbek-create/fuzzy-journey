#!/usr/bin/env python3
"""Score and sound design for the 20 s Terra Bellum trailer (tools/trailer.sh). Pure numpy, stereo 44.1 kHz, 108 bpm (36 beats = 20.0 s).

Usage: tools/trailer_score.py out.wav
The picture is cut on the same beat grid (godot/tests/trailer.gd): beat k is at k * 60 / 108 seconds.
Layers: a low D drone and a slowly opening string pad (D minor), a heartbeat that becomes war drums, a riser into the title, an impact on the war declaration,
a whoosh on each hard cut, the title hit with brass-like chord stab and a long reverb tail. Everything is mixed, soft-limited and normalised to about -14 LUFS peak-safe.
"""
import sys
import numpy as np

SR = 44100
BPM = 108.0
BEAT = 60.0 / BPM
DUR = 20.0
N = int(SR * DUR)
rng = np.random.default_rng(7)
t = np.arange(N) / SR


def beat(k):
    return k * BEAT


def env_ad(n, a, d, curve=3.0):
    """attack-decay envelope of n samples: linear attack a s, exponential-ish decay"""
    x = np.arange(n) / SR
    e = np.where(x < a, x / max(a, 1e-4), np.exp(-(x - a) * curve / max(d, 1e-4)))
    return e


def fast_lp(x, fc, passes=2):
    """cheap vectorised smoothing low-pass (moving average based) for long buffers"""
    w = max(1, int(SR / max(fc, 20.0) / 2))
    k = np.ones(w) / w
    y = x
    for _ in range(passes):
        y = np.convolve(y, k, mode="same")
    return y


def saw(f, n, phase=0.0):
    ph = (np.cumsum(np.full(n, f / SR)) + phase) % 1.0
    return 2.0 * ph - 1.0


def sine(f, n):
    return np.sin(2 * np.pi * np.cumsum(np.full(n, f / SR)))


def place(buf, sig, start_s, gain=1.0, pan=0.0):
    i = int(start_s * SR)
    if i >= N:
        return
    j = min(N, i + len(sig))
    seg = sig[: j - i] * gain
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    buf[i:j, 0] += seg * l
    buf[i:j, 1] += seg * r


def kick(n_s=0.9, f0=90.0, f1=34.0, drive=2.5):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-x * 14.0)
    ph = 2 * np.pi * np.cumsum(f / SR)
    s = np.sin(ph) * np.exp(-x * 4.2)
    s = np.tanh(s * drive)
    click = rng.standard_normal(n) * np.exp(-x * 220.0) * 0.25
    return s + fast_lp(click, 3500, 1)


def tom(f=70.0, n_s=1.1):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    f_t = f * (1.0 + 0.9 * np.exp(-x * 22.0))
    s = np.sin(2 * np.pi * np.cumsum(f_t / SR)) * np.exp(-x * 3.2)
    noise = fast_lp(rng.standard_normal(n), 900, 1) * np.exp(-x * 30.0) * 0.5
    return np.tanh((s + noise) * 1.6)


def snare_roll_hit(n_s=0.25):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    nz = rng.standard_normal(n)
    nz = nz - fast_lp(nz, 1500, 1)
    return nz * np.exp(-x * 20.0) * 0.6


def whoosh(n_s, up=True, bright=6000.0):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    nz = rng.standard_normal(n)
    e = (x / n_s) ** 2.2 if up else (1 - x / n_s) ** 2.2
    cut = 400 + (bright - 400) * (x / n_s if up else 1 - x / n_s) ** 1.5
    # a swept band: crossfade between a few fixed low-passes
    bands = [300, 900, 2200, 5000]
    out = np.zeros(n)
    lp = [fast_lp(nz, b, 1) for b in bands]
    for i, b in enumerate(bands):
        w = np.clip(1.0 - np.abs(np.log(cut / b)) / 0.9, 0.0, 1.0)
        out += lp[i] * w
    return out * e * 0.9


def impact(n_s=3.5):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    boom = sine(42.0, n) * np.exp(-x * 1.1) + 0.6 * sine(63.0, n) * np.exp(-x * 1.7)
    hit = kick(1.2, 120.0, 30.0, 3.0)
    boom[: len(hit)] += hit * 1.2
    nz = rng.standard_normal(n)
    sh = (fast_lp(nz, 4000, 1) - fast_lp(nz, 300, 1)) * np.exp(-x * 2.2) * 0.5
    return np.tanh(boom * 1.2) + sh


def reverb_ir(n_s=3.2, decay=2.2):
    n = int(SR * n_s)
    x = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-x * decay)[:, None]
    ir[:, 0] = fast_lp(ir[:, 0], 5200, 1)
    ir[:, 1] = fast_lp(ir[:, 1], 4800, 1)
    ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))[:, None]
    return ir / np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True) / 2.0 + 1e-9) * 0.05


def conv_reverb(x, ir, wet):
    out = np.zeros_like(x)
    for c in range(2):
        # FFT convolution
        n = len(x) + len(ir) - 1
        nfft = 1 << (n - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x[:, c], nfft) * np.fft.rfft(ir[:, c], nfft), nfft)[: len(x)]
        out[:, c] = y
    return x * (1 - wet * 0.5) + out * wet


# ------------------------------------------------------------------ build
dry = np.zeros((N, 2))
wetbus = np.zeros((N, 2))          # goes through the reverb

# --- drone: D1 / A1 saws, filter opening over the film, a low D underneath
drone = np.zeros(N)
for f, g in [(36.71, 0.9), (73.42, 0.5), (110.0, 0.35)]:
    for det in (-0.004, 0.0, 0.004):
        drone += saw(f * (1 + det), N, rng.random()) * g / 3
open_ = (t / DUR) ** 1.4                                        # the filter opens towards the title
drone = fast_lp(drone, 140, 2) * (1 - open_) + fast_lp(drone, 520, 2) * open_
drone *= np.interp(t, [0, 1.2, 17.2, 17.6, 20.0], [0.0, 0.5, 0.95, 0.0, 0.0])   # out at the title hit (the hit takes over)
place(dry, drone, 0.0, 0.5)

# --- string pad: D minor (D3 F3 A3 D4), slow attack, widening
pad = np.zeros((N, 2))
for k, f in enumerate([146.83, 174.61, 220.0, 293.66, 349.23]):
    for det, pan in ((-0.006, -0.8), (0.0, 0.0), (0.007, 0.8)):
        s = saw(f * (1 + det), N, rng.random())
        s = fast_lp(s, 1400, 1)
        l = np.cos((pan + 1) * np.pi / 4)
        r = np.sin((pan + 1) * np.pi / 4)
        pad[:, 0] += s * l * 0.045
        pad[:, 1] += s * r * 0.045
padenv = np.interp(t, [0, 3.0, 9.0, 16.4, 17.0, 20.0], [0.0, 0.25, 0.7, 1.0, 0.0, 0.0])
pad *= padenv[:, None]
wetbus += pad * 0.6
dry += pad * 0.7

# --- heartbeat (beats 1..15): two soft low thumps per bar, then the drums take over
for k in range(1, 16):
    place(dry, kick(0.7, 70, 32, 1.6), beat(k) + 0.0, 0.32 + 0.012 * k)
    if k % 2 == 1:
        place(dry, kick(0.6, 62, 30, 1.4), beat(k) + 0.18, 0.18)

# --- war drums from the war declaration (beat 16): toms on the beat, off-beats, rolling into the montage
tom_notes = [70.0, 58.0, 82.0, 66.0]
for k in range(16, 32):
    place(dry, tom(tom_notes[k % 4], 1.0), beat(k), 0.55)
    place(wetbus, tom(tom_notes[k % 4], 1.0), beat(k), 0.25)
    if k >= 20:
        place(dry, tom(tom_notes[(k + 1) % 4] * 1.2, 0.6), beat(k) + BEAT * 0.5, 0.3)
    if k >= 24:                                                   # sixteenths in the montage
        for sub in (0.25, 0.75):
            place(dry, snare_roll_hit(0.14), beat(k) + BEAT * sub, 0.25)
    if k >= 28:
        place(dry, snare_roll_hit(0.2), beat(k) + BEAT * 0.5, 0.45)

# --- riser into the title (beats 28..32 = 15.56 .. 17.78 s)
rs = beat(28)
rl = beat(32) - rs
ri = whoosh(rl, up=True, bright=9000.0)
place(dry, ri, rs, 0.55)
place(wetbus, ri, rs, 0.35)
# a rising tone under it
n = int(rl * SR)
x = np.arange(n) / SR
tone = np.sin(2 * np.pi * np.cumsum((110 + 440 * (x / rl) ** 2.0) / SR)) * (x / rl) ** 2 * 0.12
place(dry, tone, rs, 1.0)

# --- impact on the war declaration (beat 20 = 11.11 s) and a smaller one on the dive (beat 10)
place(dry, impact(3.4), beat(20) - 0.02, 0.85)
place(wetbus, impact(3.4), beat(20) - 0.02, 0.4)
place(dry, impact(2.4), beat(10) - 0.02, 0.45)
place(dry, whoosh(0.9, up=True, bright=5000), beat(10) - 0.9, 0.5)
place(dry, whoosh(0.8, up=True, bright=5000), beat(16) - 0.8, 0.45)

# --- whooshes on the hard cuts of the montage (frames 440..500 = beats 26.4..30, every half beat)
for k2 in np.arange(26.4, 31.0, 0.5):
    place(dry, whoosh(0.28, up=bool(int(k2 * 2) % 2), bright=7000), beat(k2) - 0.2, 0.22, pan=-0.4 if int(k2 * 2) % 2 else 0.4)

# --- the title hit (beat 32 = 17.78 s): boom + a brass-like D minor stab and a long tail
th = beat(32)
place(dry, impact(2.2) * 1.0, th - 0.02, 0.95)
place(wetbus, impact(2.2), th - 0.02, 0.6)
stab = np.zeros(int(SR * 2.2))
for f in (73.42, 146.83, 220.0, 293.66, 440.0, 587.33):
    for det in (-0.004, 0.003, 0.0):
        s = saw(f * (1 + det), len(stab), rng.random())
        stab += fast_lp(s, 1800, 1) * 0.06
stab *= env_ad(len(stab), 0.03, 1.6, 3.0)
place(dry, stab, th, 0.9)
place(wetbus, stab, th, 0.9)
# a last soft low D to close
close = sine(73.42, int(SR * 2.4)) * env_ad(int(SR * 2.4), 0.2, 2.0, 2.5) * 0.35
place(dry, close, th + 0.25, 0.8)

# --- mix: reverb bus, soft limiting, fades, peak normalisation
ir = reverb_ir(3.4, 1.9)
mix = dry + conv_reverb(wetbus, ir, 1.0) * 0.8
mix[:, 0] *= np.interp(t, [0, 0.8, 19.0, 20.0], [0, 1, 1, 0])
mix[:, 1] *= np.interp(t, [0, 0.8, 19.0, 20.0], [0, 1, 1, 0])
mix = np.tanh(mix * 1.15) / np.tanh(1.15)
mix /= np.max(np.abs(mix)) / 0.89
pcm = (mix * 32767).astype("<i2")

import wave
out = sys.argv[1] if len(sys.argv) > 1 else "trailer_score.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", out, "%.1f s" % (N / SR))
