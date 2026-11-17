#!/usr/bin/env python3
"""Renders all of Urban Fishing's music and sound effects from code.

Every sound is synthesized here (oscillators, filtered noise and a small reverb), so the
audio is original and has no outside license. The game's music is rendered from the browser
version's own Web Audio code by tools/render_web_music.js; the approximate music here is only
written with --music.

Needs numpy, scipy and ffmpeg (with libvorbis). Run from the repo root:
    python3 tools/make_audio.py
Writes godot/audio/sfx_*.ogg and amb_*.ogg.
"""
import os, subprocess, sys, tempfile, wave
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
rng = np.random.default_rng(1977)

def fq(s, base): return base * 2 ** (s / 12)

def env_exp(n, a, d, peak):
    """Attack then exponential-ish decay, like the web version's exponential ramps."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), np.exp(-(t - a) / max(d, 1e-4) * 6.9))
    return e * peak

def lp(x, f, order=2):
    f = min(max(f, 40), SR / 2 * 0.95)
    b, a = butter(order, f / (SR / 2), "low"); return lfilter(b, a, x)

def hp(x, f, order=2):
    b, a = butter(order, min(f, SR / 2 * 0.95) / (SR / 2), "high"); return lfilter(b, a, x)

def bp(x, f, q=1.5):
    lo, hi = f / (1 + 1 / (2 * q)), f * (1 + 1 / (2 * q))
    b, a = butter(2, [lo / (SR / 2), min(hi, SR / 2 * 0.95) / (SR / 2)], "band"); return lfilter(b, a, x)

def osc(kind, freq, n, vib=0.0, glide=None):
    t = np.arange(n) / SR
    f = np.full(n, freq, dtype=float)
    if glide:
        g = np.minimum(1, t / 0.09); f = freq * glide * (1 / glide) ** g
    if vib: f = f * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine": return np.sin(ph)
    if kind == "square": return np.sign(np.sin(ph)) * 0.7
    if kind == "triangle": return 2 / np.pi * np.arcsin(np.sin(ph))
    return ((ph / (2 * np.pi)) % 1) * 2 - 1     # sawtooth

def noise(n): return rng.uniform(-1, 1, n)

def impulse(seconds=1.5):
    n = int(SR * seconds); i = np.arange(n)
    return noise(n) * (1 - i / n) ** 3 * (0.6 + 0.4 * np.sin(i / 90)) * 0.06

IR = impulse()

class Track:
    def __init__(self, seconds):
        self.n = int(seconds * SR); self.dry = np.zeros(self.n + SR * 4); self.wet = np.zeros_like(self.dry)
    def add(self, t, sig, wet=False):
        i = int(t * SR); j = min(len(self.dry), i + len(sig)); self.dry[i:j] += sig[: j - i]
        if wet: self.wet[i:j] += sig[: j - i]
    # instruments, after the web version
    def pluck(self, t, f, vol, dur, kind="sawtooth", cutoff=2400, wet=False, vib=False, glide=None):
        n = int((dur + 0.05) * SR); s = osc(kind, f, n, vib, glide)
        s = lp(s, cutoff * 0.55) * env_exp(n, 0.005, dur, vol); self.add(t, s, wet)
    def kick(self, t, v):
        n = int(0.35 * SR); tt = np.arange(n) / SR
        f = 120 * (45 / 120) ** np.minimum(1, tt / 0.25); s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.004, 0.3, v); self.add(t, s)
    def hiss(self, t, kind, f, v, dur, wet=False):
        n = int((dur + 0.02) * SR); s = noise(n)
        s = bp(s, f) if kind == "bandpass" else hp(s, f)
        self.add(t, s * env_exp(n, 0.002, dur, v) * (2.2 if kind == "bandpass" else 1.0), wet)
    def pan(self, t, f, v):
        n = int(0.8 * SR); tt = np.arange(n) / SR; s = np.zeros(n)
        for m, a in [(1, 1), (2.01, 0.45), (3.98, 0.12)]:
            ff = f * m * (1.01 * (1 / 1.01) ** np.minimum(1, tt / 0.05)); s += np.sin(2 * np.pi * np.cumsum(ff) / SR) * a
        self.add(t, s * env_exp(n, 0.003, 0.7, v), True)
    def render(self, loop=True, master=0.5):
        mix = self.dry + fftconvolve(self.wet, IR)[: len(self.dry)] * 0.35 * 6
        if loop:  # wrap the tail onto the start so the loop is seamless
            out = mix[: self.n].copy(); tail = mix[self.n:]; out[: len(tail)] += tail[: self.n]
        else: out = mix
        out = np.tanh(out * master * 1.6) * 0.9
        return out

def pick(xs): return xs[rng.integers(len(xs))]

def style_surf(T, t, s, bar):
    r = [0, 0, 5, 7][bar % 4]
    if s % 8 == 0: T.kick(t, 0.7)
    if s % 8 == 4: T.hiss(t, "bandpass", 1800, 0.3, 0.14, True)
    if s % 2 == 0: T.hiss(t, "highpass", 7000, 0.06, 0.04)
    b = [0, None, 7, None, 12, None, 7, None][s % 8]
    if b is not None: T.pluck(t, fq(r + b - 12, 82.4), 0.22, 0.25, "triangle", 900)
    if s % 2 == 0 and rng.random() < 0.55: T.pluck(t, fq(r + pick([0, 3, 5, 7, 10, 12, 15]), 329.6), 0.09, 0.32, "sawtooth", 3200, True, True)
    if s == 0 and bar % 2 == 0:
        for k in [0, 4, 7]: T.pluck(t, fq(r + k, 164.8), 0.05, 1.2, "square", 1800, True)

def style_steel(T, t, s, bar):
    r = [0, 5, 7, 0][bar % 4]
    if s % 4 == 0: T.kick(t, 0.5)
    if s % 2 == 1: T.hiss(t, "highpass", 6000, 0.08, 0.05)
    if s in (6, 14): T.hiss(t, "bandpass", 2500, 0.18, 0.08)
    b = [0, None, None, 7, None, None, 4, None][s % 8]
    if b is not None: T.pluck(t, fq(r + b - 12, 65.4), 0.25, 0.3, "sine", 600)
    if s in (0, 3, 6, 8, 10, 12, 14) and rng.random() < 0.8: T.pan(t, fq(r + [0, 4, 7, 12, 9, 7, 4, 2][(s + bar * 3) % 8], 523.3), 0.1)

def style_prowl(T, t, s, bar):
    r = [0, 0, -2, -4][bar % 4]
    if s in (0, 10): T.kick(t, 0.45)
    if s % 4 == 2: T.hiss(t, "highpass", 5000, 0.05, 0.12)
    if s % 2 == 0: T.pluck(t, fq(r + [0, 3, 5, 6, 7, 6, 5, 3][(s // 2) % 8] - 12, 110), 0.2, 0.28, "triangle", 700)
    if s % 8 == 4 and rng.random() < 0.7: T.pluck(t, fq(r + pick([12, 15, 19, 22]), 220), 0.06, 1.4, "sine", 2500, True)

def style_reactor(T, t, s, bar):
    r = [0, 0, 1, -1][bar % 4]
    if s % 4 == 0: T.kick(t, 0.55)
    T.hiss(t, "highpass", 8000, 0.07 if s % 4 == 2 else 0.025, 0.02)
    T.pluck(t, fq(r - 12, 55), 0.2 if s % 4 == 0 else 0.12, 0.12, "sawtooth", 500 + (s % 8) * 120)
    if s == 0 and bar % 2 == 0:
        for k in [0, 6]: T.pluck(t, fq(r + k, 220), 0.05, 1.6, "square", 1400, True)
    if s == 8 and bar % 4 == 3: T.pluck(t, 880, 0.06, 0.18, "sine", 4000, True); T.pluck(t + 0.22, 660, 0.06, 0.18, "sine", 4000, True)

def style_miami(T, t, s, bar):
    r = [0, -4, 3, -2][bar % 4]; ch = [0, 3, 7] if bar % 4 == 0 else [0, 4, 7]
    if s % 4 == 0: T.kick(t, 0.6)
    if s in (4, 12): T.hiss(t, "bandpass", 1400, 0.28, 0.35, True)
    if s % 2 == 1: T.hiss(t, "highpass", 9000, 0.04, 0.03)
    if s % 2 == 0: T.pluck(t, fq(r + (12 if s % 4 else 0) - 12, 55), 0.2, 0.2, "sawtooth", 700)
    T.pluck(t, fq(r + ch[s % 3] + (12 if s >= 8 else 0), 220), 0.045, 0.22, "square", 2200, True)
    if s == 0:
        for k in ch: T.pluck(t, fq(r + k, 220), 0.03, 2.4, "sawtooth", 1200, True, True)

def style_swamp(T, t, s, bar):
    r = [0, 0, 5, 0, 7, 5, 0, 7][bar % 8]
    if s in (0, 8): T.kick(t, 0.5)
    if s in (4, 12): T.hiss(t, "bandpass", 3000, 0.12, 0.05)
    b = {0: 0, 3: 7, 4: 9, 8: 10, 11: 9, 12: 7}.get(s)
    if b is not None: T.pluck(t, fq(r + b - 12, 82.4), 0.22, 0.35, "triangle", 800)
    if s in (2, 10, 14) and rng.random() < 0.6: T.pluck(t, fq(r + pick([0, 3, 5, 7, 10, 12]), 164.8), 0.08, 0.9, "sawtooth", 1800, True, True, pick([0.89, 0.94]))

def style_yacht(T, t, s, bar):
    r = [5, 4, 2, 0][bar % 4]; ch = [0, 3, 7, 10] if bar % 4 in (1, 2) else [0, 4, 7, 11]
    if s in (0, 10): T.kick(t, 0.42)
    if s in (4, 12): T.hiss(t, "bandpass", 2200, 0.15, 0.12, True)
    if s % 2 == 0: T.hiss(t, "highpass", 8000, 0.03, 0.05)
    if s in (0, 3, 6, 10): T.pluck(t, fq(r + [0, 0, 7, 5][[0, 3, 6, 10].index(s)] - 12, 65.4), 0.22, 0.3, "triangle", 600)
    if s in (0, 7):
        for k in ch: T.pluck(t, fq(r + k, 261.6), 0.032, 1.1, "sine", 3000, True, True)
    if s % 4 == 2 and rng.random() < 0.45: T.pan(t, fq(r + pick([12, 14, 16, 19]), 261.6), 0.035)

STYLES = { "surf": (112, style_surf), "steel": (100, style_steel), "prowl": (88, style_prowl), "reactor": (124, style_reactor),
	"miami": (98, style_miami), "swamp": (76, style_swamp), "yacht": (94, style_yacht) }

def music(name, bars=16):
    tempo, fn = STYLES[name]; e = 60 / tempo / 4
    T = Track(bars * 16 * e)
    for st in range(bars * 16): fn(T, st * e, st % 16, st // 16)
    return T.render(True, 0.5)

# ---------- sound effects ----------
def secs(x): return int(x * SR)
def sfx_ui_click():
    n = secs(0.06); s = hp(noise(n), 2500) * env_exp(n, 0.001, 0.014, 0.5)
    return s + osc("sine", 1500, n) * env_exp(n, 0.001, 0.03, 0.15)
def sfx_ui_hover():
    n = secs(0.04); return osc("sine", 2200, n) * env_exp(n, 0.001, 0.02, 0.08)
def sfx_cast():
    n = secs(0.45); t = np.arange(n) / SR; s = noise(n); out = np.zeros(n)
    for k in range(6):  # a whoosh: a band of noise sweeping up
        a, b = k * n // 6, (k + 1) * n // 6; out[a:b] = bp(s, 600 + 2600 * k / 5, 2)[a:b]
    return out * np.sin(np.pi * t / t[-1]) ** 2 * 0.7
def sfx_plop():
    n = secs(0.35); t = np.arange(n) / SR; f = 900 * (180 / 900) ** np.minimum(1, t / 0.08)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.002, 0.1, 0.5)
    return s + lp(noise(n), 2500) * env_exp(n, 0.002, 0.18, 0.25)
def sfx_nibble():
    n = secs(0.12); return (osc("sine", 520, n) * env_exp(n, 0.001, 0.05, 0.3) + lp(noise(n), 3000) * env_exp(n, 0.001, 0.04, 0.15))
def sfx_bite():
    n = secs(0.6); s = lp(noise(n), 1800) * env_exp(n, 0.004, 0.35, 0.8); t = np.arange(n) / SR
    f = 500 * (150 / 500) ** np.minimum(1, t / 0.15); return s + np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.002, 0.15, 0.4)
def sfx_reel():
    n = secs(0.05); return bp(noise(n), 4200, 3) * env_exp(n, 0.0005, 0.012, 0.9) + osc("square", 1900, n) * env_exp(n, 0.0005, 0.01, 0.06)
def sfx_snap():
    n = secs(0.5); t = np.arange(n) / SR; f = 1800 * (600 / 1800) ** np.minimum(1, t / 0.2)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.001, 0.25, 0.35) + hp(noise(n), 3000) * env_exp(n, 0.001, 0.05, 0.6)
def sfx_splash():
    n = secs(0.5); return lp(noise(n), 1400) * env_exp(n, 0.01, 0.35, 0.7)
def jingle(notes, base, step, v, tail=1.0):
    T = Track(len(notes) * step + tail)
    for i, k in enumerate(notes):
        if k is not None: T.pan(i * step, fq(k, base), v)
    return T.render(False, 0.9)[: secs(len(notes) * step + tail)]
def sfx_catch(): return jingle([0, 4, 7, 12], 523.3, 0.09, 0.35)
def sfx_legend(): return jingle([0, 4, 7, 12, None, 7, 12, 16, 19], 523.3, 0.1, 0.32, 1.4)
def sfx_cash():
    n = secs(0.9); s = np.zeros(n); t = np.arange(n) / SR
    s[: secs(0.08)] += bp(noise(secs(0.08)), 3000) * env_exp(secs(0.08), 0.001, 0.05, 0.6)   # the drawer
    for f, d in [(2093, 0.0), (2637, 0.09)]:
        i = secs(0.12 + d); m = n - i; s[i:] += (osc("sine", f, m) + 0.4 * osc("sine", f * 2.76, m)) * env_exp(m, 0.002, 0.6, 0.25)
    return s
def sfx_whistle():
    n = secs(0.9); t = np.arange(n) / SR; f = 2600 + 160 * np.sign(np.sin(2 * np.pi * 22 * t))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.15 * bp(noise(n), 2700, 3)
    e = np.minimum(1, t / 0.02) * np.where(t < 0.3, 1, np.where(t < 0.4, 0.15, 1)) * np.clip((0.9 - t) / 0.15, 0, 1)
    return s * e * 0.3
def sfx_alert():
    n = secs(0.22); t = np.arange(n) / SR; f = 700 + 900 * np.minimum(1, t / 0.12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.005, 0.12, 0.3)
def sfx_thunder():
    n = secs(3.4); t = np.arange(n) / SR; s = noise(n); out = np.zeros(n)
    for k in range(10):
        a, b = k * n // 10, (k + 1) * n // 10; out[a:b] = lp(s, 900 * (90 / 900) ** (k / 9), 2)[a:b]
    rumble = lp(noise(n), 120) * 3
    return (out + rumble) * env_exp(n, 0.05, 3.0, 0.9) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t) * np.exp(-t))
def sfx_jet():
    n = secs(4.3); t = np.arange(n) / SR; s = noise(n); out = np.zeros(n)
    for k in range(16):
        a, b = k * n // 16, (k + 1) * n // 16; tc = t[a]
        f = 300 + 1100 * min(1, tc / 1.6) if tc < 1.6 else 1400 - 1150 * min(1, (tc - 1.6) / 2.4); out[a:b] = lp(s, f, 2)[a:b]
    e = np.where(t < 1.6, (t / 1.6) ** 2, np.exp(-(t - 1.6) * 1.6))
    return out * e * 0.9
def sfx_bell():
    n = secs(1.0); return sum(osc("sine", 1318 * m, n) * env_exp(n, 0.002, 0.8 / m ** 0.5, a) for m, a in [(1, 0.3), (2.4, 0.12), (4.1, 0.06)])
def sfx_paper():
    n = secs(0.35); t = np.arange(n) / SR; s = bp(noise(n), 3500, 1) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * t)))
    j = np.zeros(n); jj = jingle([0, 7], 1046.5, 0.07, 0.12, 0.2)[:n]; j[: len(jj)] = jj
    return s * env_exp(n, 0.03, 0.25, 0.35) + j * 0.6
def sfx_plaque(): return jingle([7, 12, 16, 19, 24], 523.3, 0.07, 0.25, 1.2)
def sfx_bus():
    n = secs(1.2); t = np.arange(n) / SR; s = hp(noise(n), 1500) * env_exp(n, 0.02, 0.6, 0.4)   # air brakes
    return s + lp(osc("sawtooth", 55, n), 300) * env_exp(n, 0.1, 1.0, 0.3)
def sfx_door():
    n = secs(0.3); return lp(noise(n), 600) * env_exp(n, 0.002, 0.08, 0.6) + osc("sine", 90, n) * env_exp(n, 0.002, 0.1, 0.4)

# ---------- ambience loops ----------
def loopify(x, xf=SR // 2):
    a = x[: xf].copy(); out = x[xf:].copy(); out[-xf:] = out[-xf:] * np.linspace(1, 0, xf) + a * np.linspace(0, 1, xf); return out
def amb_rain():
    n = secs(12); s = lp(noise(n), 5000) * 0.18 + hp(noise(n), 6000) * 0.08
    drops = np.zeros(n)
    for i in rng.integers(0, n - 2000, 900): drops[i: i + 400] += bp(noise(400), 2000 + rng.random() * 3000, 3) * env_exp(400, 0.0005, 0.006, 0.3)
    return loopify(s + drops)
def amb_night():
    n = secs(12); t = np.arange(n) / SR; s = lp(noise(n), 400) * 0.05
    for k in range(5):
        f = 4200 + k * 260; rate = 14 + k * 3; ph = rng.random() * 6
        chirp = np.sin(2 * np.pi * f * t) * (np.sin(2 * np.pi * rate * t + ph) > 0.3) * (np.sin(2 * np.pi * (0.4 + k * 0.13) * t + ph) > -0.2)
        s += lp(chirp, 6000) * 0.035
    return loopify(s)
def amb_day():
    n = secs(14); t = np.arange(n) / SR; s = lp(noise(n), 700) * 0.06 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * t))   # warm breeze
    for _ in range(9):  # birds
        i = rng.integers(0, n - secs(0.6)); m = secs(0.12 + rng.random() * 0.2); tt = np.arange(m) / SR
        f0 = 2400 + rng.random() * 1800; f = f0 * (1 + 0.25 * np.sin(2 * np.pi * (8 + rng.random() * 8) * tt))
        s[i: i + m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) * 0.05
    return loopify(s)
def amb_reel():   # held-reel ratchet, looped
    n = secs(0.6); s = np.zeros(n); c = sfx_reel()
    for i in range(0, n, secs(0.06)): s[i: i + len(c)] += c[: n - i] * 0.8
    return s

def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    # level everything to a target loudness for its kind, with the peak kept under -1 dB
    target = { "music": -21, "amb": -30 }.get(name.split("_")[0], -22)
    if name in ("sfx_ui_hover", "sfx_reel", "sfx_nibble"): target = -32
    if name in ("sfx_thunder", "sfx_jet"): target = -20
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    x = x * 10 ** ((target - rms) / 20)
    pk = np.max(np.abs(x))
    if pk > 0.89: x = x / pk * 0.89
    x = np.clip(x, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f: tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.unlink(tmp)
    print(name, "%.1fs" % (len(x) / SR))

if __name__ == "__main__":
    # the music comes from the browser version's own code: tools/render_web_music.js
    if "--music" in sys.argv:
        for k in STYLES: write("music_" + k, music(k))
    for k, fn in list(globals().items()):
        if k.startswith("sfx_") or k.startswith("amb_"): write(k, fn())
