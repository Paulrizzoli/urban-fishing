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

def sfx_horn():   # a car horn: two detuned reedy tones, two short beeps
    n = secs(0.62); t = np.arange(n) / SR; s = np.zeros(n)
    for a, b in [(0.0, 0.2), (0.27, 0.6)]:
        i, j = secs(a), secs(b); m = j - i; tt = np.arange(m) / SR
        tone = osc("sawtooth", 415, m) + osc("sawtooth", 495, m) * 0.9 + osc("square", 830, m) * 0.15
        e = np.minimum(1, tt / 0.012) * np.clip((tt[-1] - tt) / 0.03, 0, 1)
        s[i:j] += lp(tone, 2600) * e * 0.4
    return s
def sfx_boathorn():   # a boat's air horn: one long low blast
    n = secs(1.5); t = np.arange(n) / SR
    tone = osc("sawtooth", 147, n) + osc("sawtooth", 148.5, n) * 0.8 + osc("sawtooth", 294, n) * 0.25
    e = np.minimum(1, t / 0.06) * np.clip((1.5 - t) / 0.3, 0, 1)
    return lp(tone, 1100) * e * 0.45 + lp(noise(n), 500) * e * 0.04
def sfx_thump():   # a soft bump, like landing on your backside
    n = secs(0.45); t = np.arange(n) / SR; f = 140 * (55 / 140) ** np.minimum(1, t / 0.12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.003, 0.22, 0.8) + lp(noise(n), 900) * env_exp(n, 0.002, 0.08, 0.4)

# ---------- v0.9.42 sound polish: fishing ----------
def _drop(n, f0, f1, dur, amp):
    """A water drop: a sine that bends up fast, the 'bloop' at the heart of every splash."""
    t = np.arange(n) / SR; f = f0 * (f1 / f0) ** np.minimum(1, t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.001, dur * 1.6, amp)
def _spray(n, cut, dur, amp, at=0.0):
    out = np.zeros(n); i = secs(at); m = n - i
    out[i:] = lp(hp(noise(m), 300), cut) * env_exp(m, 0.004, dur, amp); return out
def _droplets(n, count, start, spread, amp):
    out = np.zeros(n)
    for _ in range(count):
        i = secs(start + rng.random() * spread); m = min(secs(0.06), n - i)
        if m <= 10: continue
        f = 1200 + rng.random() * 2200; out[i:i + m] += _drop(m, f, f * 1.6, 0.015, amp * (0.4 + 0.6 * rng.random()))
    return out
# lure and bait hitting the water, from a worm's soft plip to a popper's chug
def sfx_lure_tiny():
    n = secs(0.3); return _drop(n, 1400, 2600, 0.03, 0.35) + _spray(n, 2500, 0.06, 0.08)
def sfx_lure_small():
    n = secs(0.4); return _drop(n, 900, 1900, 0.04, 0.45) + _spray(n, 3000, 0.1, 0.18) + _droplets(n, 3, 0.05, 0.15, 0.12)
def sfx_lure_med():
    n = secs(0.55); return _drop(n, 520, 1200, 0.05, 0.55) + _spray(n, 2600, 0.18, 0.35) + _droplets(n, 6, 0.06, 0.25, 0.14)
def sfx_lure_big():
    n = secs(0.6); s = _drop(n, 260, 520, 0.06, 0.5) + _spray(n, 1800, 0.22, 0.5)
    return s + lp(noise(n), 400) * env_exp(n, 0.002, 0.12, 0.4) + _droplets(n, 8, 0.08, 0.3, 0.14)
def sfx_cast_bad():   # a sloppy cast: the whole lot slaps down
    n = secs(0.7); return _spray(n, 2200, 0.3, 0.7) + lp(noise(n), 300) * env_exp(n, 0.002, 0.1, 0.5) + _droplets(n, 12, 0.05, 0.4, 0.15)
def sfx_lure_snag():  # into a bush: a rustle of leaves and a twig snap
    n = secs(0.45); t = np.arange(n) / SR
    r = bp(noise(n), 3200, 0.8) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 17 * t))) * env_exp(n, 0.01, 0.3, 0.45)
    return r + hp(noise(n), 2000) * env_exp(n, 0.0005, 0.008, 0.6)
def sfx_lure_dirt():  # onto dry land: a little tick and skitter
    n = secs(0.3); s = np.zeros(n)
    for k, a in [(0, 0.5), (0.07, 0.25), (0.13, 0.12)]:
        i = secs(k); m = secs(0.03); s[i:i + m] += bp(noise(m), 2400, 2) * env_exp(m, 0.0005, 0.01, a)
    return s
def sfx_twitch():     # the lure skipping across the top
    n = secs(0.18); return _drop(n, 1800, 2600, 0.012, 0.2) + _spray(n, 4000, 0.04, 0.12)
def sfx_pop():        # a popper's chug: a gulp of air and water
    n = secs(0.3); t = np.arange(n) / SR
    s = lp(noise(n), 900) * env_exp(n, 0.002, 0.09, 0.6) + _drop(n, 380, 700, 0.03, 0.4)
    return s + _droplets(n, 4, 0.04, 0.15, 0.1)
# a hooked fish: the swirl when it feels the hook, and splashes that grow with the fish
def sfx_hookset():
    n = secs(0.5); t = np.arange(n) / SR; f = 1200 * (260 / 1200) ** np.minimum(1, t / 0.12)   # the line zips tight
    zip_ = bp(noise(n), 2600, 3) * env_exp(n, 0.001, 0.05, 0.5) + np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.001, 0.08, 0.15)
    return zip_ + _spray(n, 2200, 0.25, 0.55, 0.04) + _droplets(n, 6, 0.08, 0.3, 0.12)
def sfx_fish_s():
    n = secs(0.4); return _spray(n, 3200, 0.14, 0.4) + _drop(n, 800, 1500, 0.03, 0.25) + _droplets(n, 4, 0.04, 0.2, 0.12)
def sfx_fish_m():
    n = secs(0.6); s = _spray(n, 2400, 0.22, 0.6) + _spray(n, 2800, 0.12, 0.3, 0.16)
    return s + _drop(n, 450, 900, 0.05, 0.35) + _droplets(n, 8, 0.06, 0.35, 0.13)
def sfx_fish_l():
    n = secs(1.0); s = _spray(n, 1800, 0.4, 0.8) + _spray(n, 2200, 0.2, 0.45, 0.25) + lp(noise(n), 220) * env_exp(n, 0.005, 0.25, 0.7)
    return s + _drop(n, 200, 420, 0.08, 0.5) + _droplets(n, 16, 0.1, 0.6, 0.14)
def sfx_flop():       # a landed fish flapping on the bank or the deck
    n = secs(0.8); s = np.zeros(n)
    for k, a in [(0.0, 0.7), (0.18, 0.45), (0.36, 0.5), (0.58, 0.25)]:
        i = secs(k); m = secs(0.08)
        s[i:i + m] += (lp(noise(m), 1600) * env_exp(m, 0.0008, 0.03, a) + _drop(m, 300, 180, 0.02, a * 0.5))
    return s + _droplets(n, 5, 0.05, 0.6, 0.08)
def sfx_clunk():      # junk on the line: a hollow, wet clank
    n = secs(0.7); s = sum(osc("sine", f, n) * env_exp(n, 0.001, d, a) for f, d, a in [(310, 0.35, 0.3), (742, 0.2, 0.18), (1290, 0.12, 0.1)])
    return s + lp(noise(n), 1200) * env_exp(n, 0.001, 0.06, 0.4) + _droplets(n, 4, 0.1, 0.4, 0.1)

# ---------- v0.9.42: guards ----------
VOWELS = { "e": [(530, 1.0), (1840, 0.5), (2480, 0.25)], "i": [(300, 1.0), (2250, 0.45), (3000, 0.2)],
    "u": [(320, 1.0), (870, 0.4), (2240, 0.1)], "a": [(760, 1.0), (1150, 0.6), (2600, 0.2)], "o": [(560, 1.0), (900, 0.55), (2600, 0.15)] }
def _voice(dur, f0, f1, v0, v1, amp=0.5):
    """A shouted vowel: a buzzy pitch through the vowel's formants, sliding from v0 to v1."""
    n = secs(dur); t = np.arange(n) / SR; f = f0 + (f1 - f0) * (t / dur) ** 1.5
    f = f * (1 + 0.02 * np.sin(2 * np.pi * 5.5 * t)) * (1 + 0.004 * noise(n))
    src = ((np.cumsum(f) / SR) % 1) * 2 - 1 + 0.05 * noise(n)
    k = np.clip(t / dur * 1.4 - 0.2, 0, 1)
    a = sum(bp(src, ff, 6) * g for ff, g in VOWELS[v0]); b = sum(bp(src, ff, 6) * g for ff, g in VOWELS[v1])
    e = np.minimum(1, t / 0.025) * np.clip((dur - t) / 0.06, 0, 1)
    return (a * (1 - k) + b * k) * e * amp
def _cat(*parts):
    return np.concatenate(parts)
def _sil(x): return np.zeros(secs(x))
def _hiss(dur, f, amp): n = secs(dur); return hp(noise(n), f) * np.sin(np.pi * np.arange(n) / n) * amp
def sfx_shout_hey():
    return _cat(_hiss(0.07, 1200, 0.12), _voice(0.34, 250, 190, "e", "i")) + 0
def sfx_shout_heyyou():
    return _cat(_hiss(0.06, 1200, 0.1), _voice(0.24, 240, 210, "e", "i"), _sil(0.05), _voice(0.36, 260, 180, "i", "u"))
def sfx_shout_stop():
    burst = lambda a: hp(noise(secs(0.02)), 1500) * env_exp(secs(0.02), 0.0005, 0.01, a)
    return _cat(_hiss(0.14, 4500, 0.25), burst(0.4), _voice(0.3, 230, 180, "a", "o"), burst(0.3), _sil(0.1))
def sfx_bark():
    out = np.zeros(secs(0.75))
    for at in (0.0, 0.32):
        v = _voice(0.13, 520, 380, "a", "o", 0.7) + _hiss(0.13, 900, 0.15); i = secs(at); out[i:i + len(v)] += v
    return out
def sfx_cam_beep():
    n = secs(0.5); s = np.zeros(n)
    for at in (0.0, 0.18):
        i = secs(at); m = secs(0.09); s[i:i + m] += osc("square", 1760, m) * env_exp(m, 0.002, 0.08, 0.2)
    return lp(s, 5000)

# ---------- v0.9.42: vehicles ----------
def amb_engine():     # a car rolling by: engine, tyres on the road
    n = secs(4); t = np.arange(n) / SR
    eng = lp(osc("sawtooth", 46, n) + 0.6 * osc("sawtooth", 92.5, n) + 0.3 * osc("square", 138, n), 420)
    tyres = bp(noise(n), 900, 0.7) * 0.25
    return eng * (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t)) * 0.5 + tyres
def amb_motor():      # an outboard motor's putter and whine
    n = secs(4); t = np.arange(n) / SR
    puls = (np.sin(2 * np.pi * 28 * t) > 0.6).astype(float)
    put = lp(puls * (0.6 + 0.4 * noise(n)), 700)
    whine = lp(osc("sawtooth", 168, n), 1400) * 0.25 + osc("sine", 336, n) * 0.05
    water = lp(noise(n), 1500) * 0.15 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.8 * t))
    return put * 0.6 + whine + water
def sfx_paddle():     # a kayak paddle stroke: the dip, the pull and a drip
    n = secs(0.6); t = np.arange(n) / SR
    pull = bp(noise(n), 700, 0.9) * np.sin(np.pi * np.clip(t / 0.35, 0, 1)) ** 2 * 0.5
    return pull + _drop(n, 600, 1100, 0.03, 0.15) + _droplets(n, 3, 0.35, 0.2, 0.08)

# ---------- v0.9.42: footsteps ----------
def _step(body, f, dur, amp, click=0.0):
    n = secs(dur + 0.05); s = bp(noise(n), f, body) * env_exp(n, 0.002, dur, amp)
    if click: s += hp(noise(n), 3000) * env_exp(n, 0.0005, 0.006, click)
    return s + osc("sine", 90, n) * env_exp(n, 0.002, 0.03, amp * 0.2)
def _pad(x, n): y = np.zeros(n); y[: min(n, len(x))] = x[:n]; return y
def sfx_step_hard(): return _step(1.5, 1500, 0.04, 0.5, 0.25)        # sidewalk, street, concrete
def sfx_step_grass():
    n = secs(0.16); t = np.arange(n) / SR
    return bp(noise(n), 2600, 0.7) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 40 * t))) * env_exp(n, 0.01, 0.09, 0.4)
def sfx_step_sand(): n = secs(0.18); return lp(noise(n), 2200) * env_exp(n, 0.012, 0.11, 0.45)
def sfx_step_wood():  # a dock plank: a hollow knock
    n = secs(0.2); return sum(osc("sine", f, n) * env_exp(n, 0.001, d, a) for f, d, a in [(180, 0.1, 0.4), (410, 0.06, 0.2)]) + _pad(_step(2, 1100, 0.03, 0.25), n)
def sfx_step_wet():   # puddles and the flooded street
    n = secs(0.22); return _spray(n, 2600, 0.07, 0.4) + _drop(n, 700, 1300, 0.02, 0.2) + _droplets(n, 2, 0.03, 0.1, 0.08)

# ---------- v0.9.42: menus ----------
def sfx_ui_open():
    n = secs(0.22); t = np.arange(n) / SR; f = 500 * 2.2 ** np.minimum(1, t / 0.12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.004, 0.12, 0.18) + bp(noise(n), 2000, 1) * env_exp(n, 0.01, 0.1, 0.1)
def sfx_ui_close():
    n = secs(0.2); t = np.arange(n) / SR; f = 1100 * 0.45 ** np.minimum(1, t / 0.1)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.003, 0.1, 0.16) + bp(noise(n), 1500, 1) * env_exp(n, 0.01, 0.08, 0.08)
def sfx_ui_tick(): n = secs(0.03); return osc("sine", 2900, n) * env_exp(n, 0.0005, 0.012, 0.25)

# ---------- v0.9.42: weather and crowds ----------
def sfx_thunder_close():   # right overhead: a crack, then the rumble rolling off
    n = secs(4.0); t = np.arange(n) / SR
    crack = hp(noise(n), 1200) * env_exp(n, 0.001, 0.12, 1.0) + lp(noise(n), 3000) * env_exp(n, 0.002, 0.4, 0.6)
    th = np.zeros(n); r = sfx_thunder(); th[secs(0.08): secs(0.08) + len(r)] = r[: n - secs(0.08)]
    return crack + th * 0.9
def sfx_bat():             # the crack of a bat, then the crowd going up
    n = secs(2.6); t = np.arange(n) / SR
    crack = hp(noise(n), 1800) * env_exp(n, 0.0004, 0.01, 0.8) + osc("sine", 1450, n) * env_exp(n, 0.0005, 0.03, 0.3)
    return crack + _pad(np.concatenate([np.zeros(secs(0.15)), sfx_cheer()]), n) * 0.9
def sfx_cheer():
    n = secs(2.4); t = np.arange(n) / SR; s = np.zeros(n)
    for _ in range(30):
        f0 = 160 + rng.random() * 220; v = rng.choice(list(VOWELS)); d = 0.6 + rng.random() * 1.2
        i = secs(rng.random() * 0.4); vv = _voice(d, f0, f0 * (1.1 + rng.random() * 0.3), v, rng.choice(list(VOWELS)), 0.08)
        s[i:i + len(vv)] += vv[: n - i]
    return (s + bp(noise(n), 1400, 0.6) * 0.15) * np.clip(np.minimum(t / 0.25, (2.4 - t) / 1.4), 0, 1)

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
def amb_surf():   # waves rolling in and breaking on the sand
    n = secs(16); t = np.arange(n) / SR; s = np.zeros(n); base = lp(noise(n), 2500)
    for k in range(4):   # four sets of waves in the loop, a little uneven
        at = k * 4.0 + rng.random() * 0.6; e = np.exp(-np.maximum(t - at - 0.6, 0) / 1.6) * np.clip((t - at) / 0.6, 0, 1)
        s += base * e * (0.6 + 0.3 * rng.random())
    wash = bp(noise(n), 4500, 0.8) * 0.08
    return loopify(s * 0.45 + lp(noise(n), 300) * 0.25 + wash)
def amb_gulls():   # laughing gulls over the water
    n = secs(14); s = np.zeros(n)
    for _ in range(7):
        i = rng.integers(0, n - secs(1.2)); m = secs(0.22 + rng.random() * 0.12); tt = np.arange(m) / SR
        f0 = 1300 + rng.random() * 500; f = f0 * (1 + 0.35 * np.sin(np.pi * tt / tt[-1])) * (1 + 0.04 * np.sin(2 * np.pi * 30 * tt))
        call = (osc("sawtooth", 1, m) * 0)
        ph = 2 * np.pi * np.cumsum(f) / SR; call = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        call = bp(call, f0 * 1.3, 1.2) * np.sin(np.pi * tt / tt[-1]) * 0.25
        for r in range(rng.integers(1, 4)):
            j = i + r * secs(0.3); s[j:j + m] += call[: n - j] * (0.9 ** r)
    return loopify(s)
def amb_spillway():   # the dam's spillway: a deep, steady roar
    n = secs(12); t = np.arange(n) / SR
    roar = lp(noise(n), 900, 2) * 0.6 + lp(noise(n), 160, 2) * 1.4 + bp(noise(n), 2500, 0.6) * 0.12
    return loopify(roar * (0.9 + 0.1 * np.sin(2 * np.pi * 0.23 * t)))
def amb_mill():   # the old mill: a waterwheel's slow thump, gears and a loom clatter
    n = secs(12); t = np.arange(n) / SR; s = lp(noise(n), 300) * 0.15 + lp(osc("sawtooth", 50, n), 200) * 0.06
    for i in range(0, n - secs(0.3), secs(1.5)):   # the wheel's paddles
        m = secs(0.3); s[i:i + m] += lp(noise(m), 400) * env_exp(m, 0.005, 0.2, 0.6) + _drop(m, 120, 70, 0.08, 0.3)
    for i in range(secs(0.37), n - secs(0.1), secs(0.375)):   # gears and the loom
        m = secs(0.05); s[i:i + m] += bp(noise(m), 1900, 3) * env_exp(m, 0.0005, 0.02, 0.35)
    for i in range(secs(0.75), n - secs(0.3), secs(3.0)):   # a heavy clank now and then
        m = secs(0.3); s[i:i + m] += sum(osc("sine", f, m) * env_exp(m, 0.001, 0.2, a) for f, a in [(220, 0.2), (587, 0.12), (1240, 0.06)])
    return loopify(s)
def amb_crowd():   # a ballpark crowd murmuring between pitches
    n = secs(12); t = np.arange(n) / SR; s = bp(noise(n), 800, 0.5) * 0.25 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.17 * t))
    for _ in range(70):
        f0 = 120 + rng.random() * 160; d = 0.3 + rng.random() * 0.6; v = _voice(d, f0, f0 * (0.9 + rng.random() * 0.2), rng.choice(list(VOWELS)), rng.choice(list(VOWELS)), 0.05)
        i = rng.integers(0, n - len(v)); s[i:i + len(v)] += lp(v, 2200)
    for _ in range(3):   # the vendor and a few claps
        i = rng.integers(0, n - secs(1)); m = secs(0.02)
        for r in range(6): j = i + r * secs(0.14); s[j:j + m] += bp(noise(m), 1800, 1) * env_exp(m, 0.0005, 0.01, 0.15)
    return loopify(s)
def amb_city():   # downtown: traffic hum off the buildings
    n = secs(12); t = np.arange(n) / SR
    s = lp(noise(n), 400, 2) * 0.5 + bp(noise(n), 1100, 0.5) * 0.08 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t))
    return loopify(s + lp(osc("sawtooth", 55, n), 160) * 0.04)
def amb_fountain():   # a plaza fountain: a jet and water falling back into the pool
    n = secs(8); s = hp(lp(noise(n), 6000), 500) * 0.25
    for i in rng.integers(0, n - 2000, 500): s[i:i + 600] += _drop(600, 800 + rng.random() * 2500, 2500, 0.01, 0.06)
    return loopify(s)
def amb_hum():   # the power station: transformer hum
    n = secs(6); s = sum(osc("sine", 60 * k, n) * a for k, a in [(1, 0.25), (2, 0.4), (3, 0.12), (4, 0.15), (6, 0.05)])
    return loopify(s + bp(noise(n), 120, 2) * 0.1)
def amb_wind():   # gusts for windy and stormy days
    n = secs(14); t = np.arange(n) / SR; g = 0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * t) * np.sin(2 * np.pi * 0.23 * t + 1)
    s = np.zeros(n); base = noise(n)
    for k in range(14):
        a, b = k * n // 14, (k + 1) * n // 14; s[a:b] = bp(base, 300 + 500 * g[a], 1.2)[a:b]
    return loopify(s * (0.4 + 0.6 * g) + lp(noise(n), 200) * 0.2)
def amb_drag():   # the drag ratchet screaming as a fish takes line
    n = secs(0.5); s = np.zeros(n); c = sfx_reel()
    for i in range(0, n, secs(0.018)): s[i: i + len(c)] += c[: n - i] * 0.7
    return s + bp(noise(n), 3000, 2) * 0.1
def amb_line():   # a line under strain: a thin singing whine
    n = secs(3); t = np.arange(n) / SR
    s = osc("sine", 2100, n) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.3 * t)) * 0.15 + bp(noise(n), 2400, 8) * 0.3
    creak = bp(noise(n), 500, 4) * (np.sin(2 * np.pi * 1.4 * t) > 0.85) * 0.4
    return s + creak
def amb_reel():   # held-reel ratchet, looped
    n = secs(0.6); s = np.zeros(n); c = sfx_reel()
    for i in range(0, n, secs(0.06)): s[i: i + len(c)] += c[: n - i] * 0.8
    return s

def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    # level everything to a target loudness for its kind, with the peak kept under -1 dB
    target = { "music": -21, "amb": -30 }.get(name.split("_")[0], -22)
    if name in ("sfx_ui_hover", "sfx_reel", "sfx_nibble"): target = -32
    if name in ("sfx_thunder", "sfx_jet", "sfx_thunder_close"): target = -20
    quiet = { "sfx_ui_tick": -34, "sfx_ui_open": -30, "sfx_ui_close": -31, "sfx_lure_tiny": -28, "sfx_twitch": -30, "sfx_cam_beep": -28,
        "sfx_step_hard": -31, "sfx_step_grass": -32, "sfx_step_sand": -32, "sfx_step_wood": -30, "sfx_step_wet": -30, "sfx_paddle": -29,
        "amb_engine": -24, "amb_motor": -24, "amb_drag": -26, "amb_line": -30, "amb_spillway": -24, "amb_city": -30, "amb_hum": -30 }
    target = quiet.get(name, target)
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
    # name some sounds to render just those, e.g. python3 tools/make_audio.py sfx_horn
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for k, fn in list(globals().items()):
        if (k.startswith("sfx_") or k.startswith("amb_")) and (not only or k in only): write(k, fn())
