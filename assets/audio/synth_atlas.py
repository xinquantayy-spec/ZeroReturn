#!/usr/bin/env python3
"""Zero Return - procedural sound atlas (original synthesis, no samples).
All short effects live in ONE audio asset; the game plays regions of it (Sound.PlaybackRegion), which keeps the
monthly audio-upload quota for music/ambience.
Usage: python3 assets/audio/synth_atlas.py <out_dir> <luau_out>
  -> <out_dir>/ZR_SFX_Atlas.ogg  and  <luau_out> (SoundAtlas.luau: name -> {start, length, gain})
"""
import sys, os, json, subprocess, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(7031)
GAP = 0.09


def T(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, decay):
    x = np.arange(n) / SR
    return np.clip(x / max(attack, 1e-4), 0, 1) * np.exp(-x / decay)


def bell(n, peak=0.5, width=0.25):
    x = np.linspace(0, 1, n)
    return np.exp(-((x - peak) / width) ** 2)


def bp(s, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), s)


def lp(s, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), s)


def hp(s, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), s)


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def norm(s, peak=0.9):
    return s / (np.max(np.abs(s)) + 1e-9) * peak


def fit(s, sec):
    out = np.zeros(int(SR * sec))
    out[: min(len(s), len(out))] = s[: len(out)]
    return out


def at(base, s, t0, g=1.0):
    i = int(SR * t0)
    j = min(len(base), i + len(s))
    if i < len(base):
        base[i:j] += s[: j - i] * g
    return base


def room(s, length=0.25, decay=0.06, tone=3500, wet=0.25):
    n = int(SR * length)
    ir = lp(rng.standard_normal(n) * np.exp(-np.arange(n) / SR / decay), tone)
    ir /= np.max(np.abs(ir)) + 1e-9
    c = np.convolve(s, ir)[: len(s) + n] * 0.05
    out = np.zeros(len(s) + n)
    out[: len(s)] += s
    out[: len(c)] += c / (np.max(np.abs(c)) + 1e-9) * np.max(np.abs(s)) * wet
    return out


def click(freq, length=0.04, nz=0.6, dec=0.006):
    n = int(SR * length)
    x = T(length)
    return np.sin(2 * np.pi * freq * x) * env(n, 0.0003, dec) + nz * hp(rng.standard_normal(n), 2000) * env(n, 0.0002, dec * 0.7)


def ring(freqs, length, decay, amps=None):
    x = T(length)
    s = np.zeros(len(x))
    for i, f in enumerate(freqs):
        a = amps[i] if amps else 1.0 / (i + 1)
        s += a * np.sin(2 * np.pi * f * x + rng.uniform(0, 6.28)) * np.exp(-x / (decay * (1 - i * 0.12)))
    return s


def slide(length, lo, hi, dec=0.03):
    n = int(SR * length)
    return bp(rng.standard_normal(n), lo, hi) * bell(n, 0.4, 0.3) * np.exp(-np.arange(n) / SR / max(dec, 0.01) * 0.2)


# ── footsteps ────────────────────────────────────────────────────────────────
def step_concrete(v):
    L = 0.26
    n = int(SR * L)
    heel = lp(rng.standard_normal(n), 520 + v * 60) * env(n, 0.002, 0.022)
    s = heel * 1.3
    scuff = bp(rng.standard_normal(n), 1400 + v * 200, 4200) * env(n, 0.004, 0.035)
    s = at(s, scuff, 0.012 + v * 0.004, 0.55)
    grit = hp(rng.standard_normal(n), 5200) * env(n, 0.001, 0.012)
    s = at(s, grit, 0.02, 0.25)
    return norm(room(s, 0.18, 0.04, 3000, 0.18), 0.85)


def step_metal(v):
    L = 0.4
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 700) * env(n, 0.002, 0.02) * 1.1
    s += ring([380 + v * 40, 1130 + v * 70, 2350 + v * 90, 3480], L, 0.09) * 0.45
    s = at(s, bp(rng.standard_normal(n), 2000, 6000) * env(n, 0.001, 0.01), 0.004, 0.4)
    return norm(s, 0.8)


def step_gravel(v):
    L = 0.3
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 450) * env(n, 0.003, 0.03)
    grains = np.zeros(n)
    for _ in range(28 + v * 6):
        i = int(rng.uniform(0.005, 0.16) * SR)
        g = hp(rng.standard_normal(int(SR * 0.004)), 2500) * np.exp(-np.arange(int(SR * 0.004)) / SR / 0.0012)
        grains[i:i + len(g)] += g[: max(0, n - i)] * rng.uniform(0.2, 1.0)
    s += bp(grains, 1200, 7500) * 0.9
    return norm(s, 0.8)


def step_wood(v):
    L = 0.3
    n = int(SR * L)
    s = bp(rng.standard_normal(n), 140 + v * 20, 520) * env(n, 0.002, 0.05) * 1.4
    s += ring([210 + v * 15, 460], L, 0.05) * 0.4
    s = at(s, click(2400, 0.03, 0.8), 0.003, 0.35)
    return norm(room(s, 0.2, 0.05, 2500, 0.2), 0.8)


def step_dirt(v):
    L = 0.28
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 380) * env(n, 0.008, 0.04) * 1.2
    s += bp(rng.standard_normal(n), 600, 2200) * env(n, 0.015, 0.05) * 0.5
    return norm(s, 0.75)


def land():
    L = 0.5
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 300) * env(n, 0.002, 0.06) * 1.6
    s += np.sin(2 * np.pi * np.cumsum(90 * np.exp(-T(L) * 12) + 40) / SR) * env(n, 0.002, 0.08)
    for k in range(4):  # gear rattle
        s = at(s, click(rng.uniform(1800, 3200), 0.05, 0.9, 0.008), 0.03 + k * rng.uniform(0.02, 0.05), 0.25)
    return norm(s, 0.9)


def cloth(v):
    L = 0.45 + v * 0.1
    n = int(SR * L)
    mod = lp(np.abs(rng.standard_normal(n)), 18)
    s = bp(rng.standard_normal(n), 500, 3400) * mod * bell(n, 0.45, 0.35)
    return norm(s, 0.6)


def gear_rattle():
    L = 0.35
    s = np.zeros(int(SR * L))
    for k in range(5):
        s = at(s, click(rng.uniform(1500, 3800), 0.05, 1.0, 0.006), rng.uniform(0, 0.25), rng.uniform(0.3, 0.8))
    return norm(s, 0.6)


def breath(length=0.8, lo=280, hi=1300):
    n = int(SR * length)
    s = bp(rng.standard_normal(n), lo, hi) * bell(n, 0.35, 0.3)
    return norm(s, 0.55)


# ── weapon handling ──────────────────────────────────────────────────────────
def shell_insert():
    s = np.zeros(int(SR * 0.22))
    s = at(s, slide(0.08, 900, 3500), 0.0, 0.6)
    s = at(s, click(2100, 0.05, 1.0, 0.007), 0.07, 1.0)
    return norm(s, 0.8)


def pump(back=True):
    s = np.zeros(int(SR * 0.22))
    s = at(s, slide(0.1, 700, 2600), 0.0, 0.8)
    s = at(s, click(1500 if back else 1800, 0.06, 1.2, 0.01), 0.09, 1.0)
    s = at(s, lp(rng.standard_normal(int(SR * 0.05)), 800) * env(int(SR * 0.05), 0.001, 0.012), 0.095, 0.7)
    return norm(s, 0.85)


def bolt(part):
    if part == "up":
        return norm(click(2600, 0.06, 0.9, 0.008), 0.7)
    if part == "back":
        s = np.zeros(int(SR * 0.2))
        s = at(s, slide(0.12, 1200, 4200), 0.0, 0.8)
        return norm(at(s, click(1900, 0.05, 1.0, 0.008), 0.12, 0.9), 0.8)
    if part == "fwd":
        s = np.zeros(int(SR * 0.2))
        s = at(s, slide(0.1, 1000, 3800), 0.0, 0.7)
        return norm(at(s, click(1600, 0.06, 1.1, 0.01), 0.1, 1.0), 0.85)
    return norm(click(2300, 0.05, 1.0, 0.007), 0.7)


def mag(out=True):
    s = np.zeros(int(SR * 0.3))
    if out:
        s = at(s, click(1900, 0.05, 0.8, 0.007), 0.0, 0.9)
        s = at(s, slide(0.14, 400, 2500), 0.03, 0.8)
    else:
        s = at(s, slide(0.08, 500, 2200), 0.0, 0.6)
        s = at(s, click(1350, 0.08, 1.2, 0.012), 0.08, 1.0)
        s = at(s, lp(rng.standard_normal(int(SR * 0.06)), 900) * env(int(SR * 0.06), 0.001, 0.015), 0.085, 1.0)
    return norm(s, 0.85)


def selector():
    return norm(click(3100, 0.03, 0.5, 0.004) + 0.5 * click(1700, 0.03, 0.0, 0.003), 0.55)


def knife_whoosh():
    L = 0.32
    n = int(SR * L)
    x = T(L)
    src = rng.standard_normal(n)
    # sweeping band: crude time-varying filter by mixing two bands
    low = bp(src, 250, 900) * bell(n, 0.35, 0.22)
    high = bp(src, 900, 2600) * bell(n, 0.55, 0.18)
    return norm(low + high * 0.8, 0.7)


def knife_hit():
    L = 0.3
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 420) * env(n, 0.002, 0.04) * 1.4
    s += bp(rng.standard_normal(n), 700, 2400) * env(n, 0.004, 0.05) * 0.5
    return norm(s, 0.8)


# ── impacts / ballistics ─────────────────────────────────────────────────────
def impact_concrete(v):
    L = 0.32
    n = int(SR * L)
    s = hp(rng.standard_normal(n), 2600) * env(n, 0.0003, 0.008) * 1.2
    s += bp(rng.standard_normal(n), 500, 3000) * env(n, 0.001, 0.03 + v * 0.01)
    debris = np.zeros(n)
    for _ in range(10):
        debris = at(debris, click(rng.uniform(2500, 6000), 0.02, 1.0, 0.003), rng.uniform(0.02, 0.2), rng.uniform(0.1, 0.4))
    return norm(room(s + debris, 0.2, 0.05, 4000, 0.2), 0.85)


def impact_metal(v):
    L = 0.5
    n = int(SR * L)
    s = hp(rng.standard_normal(n), 3000) * env(n, 0.0002, 0.005)
    s += ring([1250 + v * 300, 2700 + v * 200, 4100, 5300], L, 0.11, [1, 0.7, 0.5, 0.3]) * 0.7
    return norm(s, 0.8)


def impact_dirt(v):
    L = 0.3
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 500) * env(n, 0.001, 0.035) * 1.4
    s += bp(rng.standard_normal(n), 1500, 6000) * env(n, 0.006, 0.06) * 0.45
    return norm(s, 0.8)


def impact_wood(v):
    L = 0.3
    n = int(SR * L)
    s = bp(rng.standard_normal(n), 300, 1600) * env(n, 0.0005, 0.03) * 1.3
    s += ring([520 + v * 50, 1240], L, 0.04) * 0.4
    s = at(s, click(3000, 0.03, 1.0, 0.004), 0.0, 0.6)
    return norm(s, 0.8)


def impact_body(v):
    L = 0.28
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 320 + v * 60) * env(n, 0.001, 0.045) * 1.5
    s += np.sin(2 * np.pi * np.cumsum(140 * np.exp(-T(L) * 20) + 55) / SR) * env(n, 0.001, 0.04) * 0.8
    return norm(s, 0.85)


def crack(v):
    L = 0.22
    n = int(SR * L)
    s = np.zeros(n)
    w = int(SR * (0.0016 + v * 0.0004))  # N-wave
    s[:w] = np.linspace(1, -1, w)
    s = hp(s, 900) * 1.4
    s += hp(rng.standard_normal(n), 3000) * env(n, 0.0005, 0.02 + v * 0.005) * 0.5
    return norm(room(s, 0.25, 0.08, 6000, 0.3), 0.9)


def whiz():
    L = 0.25
    n = int(SR * L)
    s = bp(rng.standard_normal(n), 1800, 6500) * bell(n, 0.5, 0.2)
    return norm(s, 0.6)


# ── interaction / medical ────────────────────────────────────────────────────
def rip():
    L = 0.7
    n = int(SR * L)
    s = bp(rng.standard_normal(n), 900, 6000)
    gate = (np.sin(2 * np.pi * 38 * T(L) + rng.uniform(0, 3)) > -0.2).astype(float)
    gate = lp(gate, 200)
    return norm(s * gate * bell(n, 0.45, 0.4), 0.7)


def injector():
    s = np.zeros(int(SR * 0.5))
    s = at(s, click(2200, 0.05, 1.0, 0.008), 0.0, 1.0)
    s = at(s, hp(rng.standard_normal(int(SR * 0.3)), 3000) * bell(int(SR * 0.3), 0.3, 0.3), 0.06, 0.4)
    return norm(s, 0.7)


def zipper():
    L = 0.55
    n = int(SR * L)
    teeth = np.zeros(n)
    k = 0.0
    while k < 0.45:
        teeth = at(teeth, click(rng.uniform(2500, 4200), 0.012, 1.0, 0.002), k, rng.uniform(0.4, 1.0))
        k += rng.uniform(0.008, 0.014)
    return norm(bp(teeth, 1500, 8000) * bell(n, 0.45, 0.4), 0.6)


def rummage():
    L = 0.7
    s = cloth(1)[: int(SR * L)]
    s = fit(s, L)
    for _ in range(6):
        s = at(s, click(rng.uniform(900, 2500), 0.04, 1.0, 0.01), rng.uniform(0.05, 0.6), rng.uniform(0.15, 0.4))
    return norm(s, 0.6)


def door(open_=True):
    L = 0.9 if open_ else 0.6
    n = int(SR * L)
    if open_:
        x = T(L)
        f = 180 + 90 * np.sin(2 * np.pi * 1.3 * x) + 40 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)) * 0.05
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * bell(n, 0.5, 0.35) * 0.4
        s += bp(rng.standard_normal(n), 300, 1800) * bell(n, 0.5, 0.4) * 0.3
        s = at(s, click(1200, 0.06, 1.0, 0.01), 0.0, 0.6)
    else:
        s = lp(rng.standard_normal(n), 400) * env(n, 0.001, 0.06) * 1.5
        s = at(s, click(1500, 0.06, 1.0, 0.012), 0.0, 0.7)
        s = room(s, 0.3, 0.09, 2500, 0.35)
    return norm(s, 0.8)


SOUNDS = {}


def add(name, sig, gain=1.0):
    SOUNDS[name] = (sig, gain)


for v in range(4):
    add(f"step_concrete_{v + 1}", step_concrete(v))
for v in range(3):
    add(f"step_metal_{v + 1}", step_metal(v))
    add(f"step_gravel_{v + 1}", step_gravel(v))
for v in range(2):
    add(f"step_wood_{v + 1}", step_wood(v))
    add(f"step_dirt_{v + 1}", step_dirt(v))
add("land", land())
add("cloth_1", cloth(0), 0.7)
add("cloth_2", cloth(1), 0.7)
add("gear_rattle", gear_rattle(), 0.6)
add("breath_heavy", breath(0.9), 0.6)
add("breath_release", breath(0.45, 350, 1600), 0.5)
add("shell_insert", shell_insert())
add("pump_back", pump(True))
add("pump_fwd", pump(False))
for part in ("up", "back", "fwd", "down"):
    add("bolt_" + part, bolt(part))
add("mag_out", mag(True))
add("mag_in", mag(False))
add("selector", selector(), 0.6)
add("knife_whoosh", knife_whoosh())
add("knife_hit", knife_hit())
for v in range(3):
    add(f"impact_concrete_{v + 1}", impact_concrete(v))
for v in range(2):
    add(f"impact_metal_{v + 1}", impact_metal(v))
    add(f"impact_dirt_{v + 1}", impact_dirt(v))
    add(f"impact_wood_{v + 1}", impact_wood(v))
    add(f"impact_body_{v + 1}", impact_body(v))
    add(f"crack_{v + 1}", crack(v))
add("whiz", whiz(), 0.7)
add("bandage_rip", rip())
add("injector", injector())
add("zipper", zipper())
add("rummage", rummage())
add("door_open", door(True))
add("door_close", door(False))


def write_ogg(path, sig):
    wav = path[:-4] + ".wav"
    data = (np.clip(sig, -1, 1) * 32767).astype(np.int16)
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", path], check=True)
    os.remove(wav)


if __name__ == "__main__":
    out_dir, luau = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    parts, index, cur = [], {}, GAP
    parts.append(np.zeros(int(SR * GAP)))
    for name, (sig, gain) in SOUNDS.items():
        sig = sig.astype(np.float64)
        # fade tail to silence so regions never click
        fade = min(len(sig), int(SR * 0.01))
        sig[-fade:] *= np.linspace(1, 0, fade)
        index[name] = (round(cur, 4), round(len(sig) / SR, 4), gain)
        parts.append(sig)
        parts.append(np.zeros(int(SR * GAP)))
        cur += len(sig) / SR + GAP
    atlas = np.concatenate(parts)
    write_ogg(os.path.join(out_dir, "ZR_SFX_Atlas.ogg"), atlas)
    lines = ["--!strict", "-- GENERATED by assets/audio/synth_atlas.py: regions of the ZR_SFX_Atlas audio asset (seconds).",
             "-- id is filled in after upload (Sounds.ATLAS). name = { start, length, gain }", "return {"]
    for name, (s0, ln, g) in index.items():
        lines.append(f"\t{name} = {{ {s0}, {ln}, {g} }},")
    lines.append("}")
    with open(luau, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"atlas {len(atlas) / SR:.2f}s, {len(index)} sounds")
