#!/usr/bin/env python3
"""Zero Return - procedural environment sound atlas (M10, original synthesis, no samples).
Loops (rain, rain on a roof, wind, night insects) are seamless: the game loops their region (Sound.LoopRegion).
One-shots: wind gust, thunder, gulls, ship horn, metal creak, locked door, key, keycard, loot pickup, UI.
Usage: python3 assets/audio/synth_env.py <out_dir> <luau_out>
  -> <out_dir>/ZR_SFX_Env.ogg  and  <luau_out> (EnvAtlas.luau: name -> {start, length, gain, loop})
"""
import sys, os, subprocess, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(1010)
GAP = 0.12


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


def at(base, s, t0, g=1.0):
    i = int(SR * t0)
    j = min(len(base), i + len(s))
    if i < len(base):
        base[i:j] += s[: j - i] * g
    return base


def click(freq, length=0.04, nz=0.6, dec=0.006):
    n = int(SR * length)
    x = T(length)
    return np.sin(2 * np.pi * freq * x) * env(n, 0.0003, dec) + nz * hp(rng.standard_normal(n), 2000) * env(n, 0.0002, dec * 0.7)


def reverb(s, length=1.2, decay=0.35, tone=3000, wet=0.35):
    n = int(SR * length)
    ir = lp(rng.standard_normal(n) * np.exp(-np.arange(n) / SR / decay), tone)
    ir /= np.max(np.abs(ir)) + 1e-9
    c = np.convolve(s, ir)
    out = np.zeros(len(c))
    out[: len(s)] += s
    out += c / (np.max(np.abs(c)) + 1e-9) * np.max(np.abs(s)) * wet
    return out


def seamless(s, xfade=0.6):
    """Make s loop seamlessly: crossfade its tail into its head and drop the tail."""
    n = int(SR * xfade)
    head, tail = s[:n].copy(), s[-n:].copy()
    k = np.linspace(0, 1, n)
    out = s[:-n].copy()
    out[:n] = head * np.sqrt(k) + tail * np.sqrt(1 - k)
    return out


# ── loops ────────────────────────────────────────────────────────────────────
def rain_loop(sec=8.6, roof=False):
    n = int(SR * sec)
    if roof:
        # rain on a roof heard from inside: low rumble, soft patter, an occasional heavier drip
        s = lp(rng.standard_normal(n), 700) * 0.9 + bp(rng.standard_normal(n), 700, 2200) * 0.25
        k = 0.0
        while k < sec - 0.2:
            s = at(s, lp(click(rng.uniform(500, 1200), 0.05, 1.0, 0.012), 2000), k, rng.uniform(0.1, 0.35))
            k += rng.exponential(0.035)
        for _ in range(int(sec * 1.2)):
            s = at(s, click(rng.uniform(1800, 2600), 0.08, 0.4, 0.02), rng.uniform(0, sec - 0.2), rng.uniform(0.2, 0.45))
        s *= 1 + 0.12 * np.sin(2 * np.pi * T(sec) / sec * 2)
    else:
        # outdoor rain: broadband hiss with a dense bed of tiny droplet ticks
        s = bp(rng.standard_normal(n), 400, 9000) * 0.55 + hp(rng.standard_normal(n), 3500) * 0.25
        k = 0.0
        while k < sec - 0.1:
            s = at(s, click(rng.uniform(2500, 7000), 0.012, 1.0, 0.0025), k, rng.uniform(0.04, 0.22))
            k += rng.exponential(0.006)
        s = lp(s, 11000)
        s *= 1 + 0.08 * np.sin(2 * np.pi * T(sec) / sec * 3)
    return norm(seamless(s), 0.8)


def wind_loop(sec=10.6):
    n = int(SR * sec)
    x = T(sec)
    base = rng.standard_normal(n)
    # slow gusting: amplitude and brightness follow a smooth random curve (whole cycles so it loops)
    g = 0.55 + 0.25 * np.sin(2 * np.pi * x / sec * 2 + 0.7) + 0.15 * np.sin(2 * np.pi * x / sec * 5 + 2.1)
    low = lp(base, 260) * 1.2
    mid = bp(base, 300, 1200) * 0.35
    whistle = bp(rng.standard_normal(n), 600, 900) * 0.18 * np.clip(g - 0.6, 0, 1) * 3
    s = (low + mid * g + whistle) * g
    return norm(seamless(s, 1.0), 0.75)


def crickets_loop(sec=6.4):
    n = int(SR * sec)
    s = np.zeros(n)
    # three insects at different pitches and rhythms, plus a faint distant chorus
    for f, rate, burst, g in ((4300, 2.1, 0.32, 0.5), (4900, 1.4, 0.24, 0.35), (3800, 3.0, 0.18, 0.25)):
        t = rng.uniform(0, 0.4)
        while t < sec - 0.4:
            m = int(SR * burst)
            x = T(burst)
            pulses = (np.sin(2 * np.pi * 34 * x) > 0.2).astype(float)
            chirp = np.sin(2 * np.pi * f * x) * lp(pulses, 400) * bell(m, 0.5, 0.35)
            s = at(s, chirp, t, g)
            t += 1 / rate + rng.uniform(-0.05, 0.05)
    s += bp(rng.standard_normal(n), 3500, 5500) * 0.04
    return norm(seamless(s, 0.4), 0.55)


# ── one-shots ────────────────────────────────────────────────────────────────
def wind_gust():
    L = 3.2
    n = int(SR * L)
    s = lp(rng.standard_normal(n), 380) * 1.1 + bp(rng.standard_normal(n), 400, 1600) * 0.4
    s *= bell(n, 0.45, 0.32)
    return norm(s, 0.8)


def thunder(v):
    L = 6.5
    n = int(SR * L)
    s = np.zeros(n)
    # initial crack (closer) or soft onset (distant), then rolling rumbles
    if v == 0:
        s = at(s, hp(rng.standard_normal(int(SR * 0.4)), 900) * env(int(SR * 0.4), 0.002, 0.08), 0.0, 0.9)
    for _ in range(9):
        m = int(SR * rng.uniform(0.8, 2.2))
        r = lp(rng.standard_normal(m), rng.uniform(90, 220)) * bell(m, 0.3, 0.4)
        s = at(s, r, rng.uniform(0.0, 3.6), rng.uniform(0.5, 1.2))
    s = lp(s, 1200) * np.exp(-T(L) / 2.6)
    return norm(s, 0.95)


def gull(v):
    L = 1.3
    s = np.zeros(int(SR * L))
    calls = 2 if v == 0 else 3
    t = 0.0
    for c in range(calls):
        d = rng.uniform(0.22, 0.34)
        m = int(SR * d)
        x = T(d)
        f0 = rng.uniform(1300, 1650)
        f = f0 * (1 - 0.35 * x / d) + 120 * np.sin(2 * np.pi * 18 * x)
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        rough = 1 + 0.4 * np.sin(2 * np.pi * 70 * x)
        call = tone * rough * bell(m, 0.35, 0.3)
        s = at(s, call, t, 1.0 - c * 0.15)
        t += d + rng.uniform(0.06, 0.12)
    s = reverb(bp(s, 700, 6000), 0.8, 0.25, 4000, 0.25)
    return norm(s, 0.6)


def ship_horn():
    L = 4.2
    n = int(SR * L)
    x = T(L)
    f = 98
    tone = sum(np.sin(2 * np.pi * f * k * x + rng.uniform(0, 6)) / k for k in range(1, 7))
    tone *= np.clip(x / 0.25, 0, 1) * np.clip((3.1 - x) / 0.5, 0, 1)
    s = reverb(lp(tone, 900), 2.5, 0.9, 900, 0.6)
    return norm(lp(s, 700), 0.7)


def metal_creak():
    L = 1.8
    n = int(SR * L)
    x = T(L)
    f = 120 + 60 * np.sin(2 * np.pi * 0.7 * x) + 25 * np.sin(2 * np.pi * 3.1 * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    stick = (np.sin(2 * np.pi * 28 * x + np.sin(2 * np.pi * 5 * x)) > 0.6).astype(float)
    s = (np.sin(ph) + 0.6 * np.sin(2.01 * ph) + 0.3 * np.sin(3.03 * ph)) * (0.4 + 0.6 * lp(stick, 300))
    s *= bell(n, 0.5, 0.38)
    s = reverb(bp(s, 90, 2400), 1.0, 0.35, 2000, 0.4)
    return norm(s, 0.6)


def door_locked():
    s = np.zeros(int(SR * 0.6))
    for k in range(4):
        s = at(s, click(rng.uniform(900, 1400), 0.05, 1.0, 0.012), 0.02 + k * rng.uniform(0.07, 0.11), rng.uniform(0.5, 1.0))
    s = at(s, lp(rng.standard_normal(int(SR * 0.3)), 500) * env(int(SR * 0.3), 0.002, 0.05), 0.05, 0.5)
    return norm(s, 0.75)


def key_unlock():
    s = np.zeros(int(SR * 0.85))
    # jingle, insert scrape, two-stage turn, bolt
    for _ in range(6):
        s = at(s, click(rng.uniform(3500, 6000), 0.06, 0.5, 0.02), rng.uniform(0.0, 0.18), rng.uniform(0.15, 0.35))
    m = int(SR * 0.16)
    s = at(s, bp(rng.standard_normal(m), 2500, 7000) * bell(m, 0.5, 0.35), 0.22, 0.35)
    s = at(s, click(1800, 0.04, 0.8, 0.008), 0.45, 0.7)
    s = at(s, click(1200, 0.06, 1.0, 0.012), 0.58, 0.9)
    s = at(s, lp(rng.standard_normal(int(SR * 0.12)), 600) * env(int(SR * 0.12), 0.001, 0.03), 0.6, 0.6)
    return norm(s, 0.75)


def keycard():
    s = np.zeros(int(SR * 0.75))
    m = int(SR * 0.12)
    for k, f in enumerate((1568, 2093)):
        tone = np.sin(2 * np.pi * f * T(0.12)) * np.clip(np.arange(m) / (SR * 0.004), 0, 1) * np.clip((m - np.arange(m)) / (SR * 0.01), 0, 1)
        s = at(s, tone, 0.05 + k * 0.14, 0.5)
    s = at(s, lp(rng.standard_normal(int(SR * 0.2)), 400) * env(int(SR * 0.2), 0.001, 0.05), 0.42, 0.9)
    s = at(s, click(900, 0.06, 1.0, 0.015), 0.42, 0.8)
    return norm(s, 0.7)


def loot_pickup():
    s = np.zeros(int(SR * 0.42))
    m = int(SR * 0.3)
    s = at(s, bp(rng.standard_normal(m), 500, 4000) * bell(m, 0.35, 0.3), 0.0, 0.5)
    s = at(s, lp(click(420, 0.08, 0.6, 0.02), 2500), 0.2, 0.8)
    return norm(s, 0.6)


def ui_click():
    s = click(2400, 0.05, 0.3, 0.006)
    return norm(s, 0.5)


def ui_buy():
    s = np.zeros(int(SR * 0.55))
    for k in range(4):
        s = at(s, np.sin(2 * np.pi * rng.uniform(3200, 4200) * T(0.25)) * env(int(SR * 0.25), 0.0005, 0.05), 0.05 + k * 0.06, 0.4)
    s = at(s, click(700, 0.08, 0.8, 0.02), 0.0, 0.6)
    return norm(s, 0.55)


def ui_deny():
    L = 0.28
    x = T(L)
    s = (np.sign(np.sin(2 * np.pi * 150 * x)) * 0.5 + np.sin(2 * np.pi * 300 * x) * 0.3) * env(len(x), 0.004, 0.12)
    return norm(lp(s, 1800), 0.45)


SOUNDS = {}


def add(name, sig, gain=1.0, loop=False):
    SOUNDS[name] = (sig, gain, loop)


add("rain_loop", rain_loop(), 0.8, True)
add("rain_roof_loop", rain_loop(roof=True), 0.8, True)
add("wind_loop", wind_loop(), 0.7, True)
add("crickets_loop", crickets_loop(), 0.5, True)
add("wind_gust", wind_gust(), 0.7)
add("thunder_1", thunder(0), 1.0)
add("thunder_2", thunder(1), 1.0)
add("gull_1", gull(0), 0.6)
add("gull_2", gull(1), 0.6)
add("ship_horn", ship_horn(), 0.8)
add("metal_creak", metal_creak(), 0.6)
add("door_locked", door_locked(), 0.8)
add("key_unlock", key_unlock(), 0.8)
add("keycard", keycard(), 0.8)
add("loot_pickup", loot_pickup(), 0.7)
add("ui_click", ui_click(), 0.6)
add("ui_buy", ui_buy(), 0.6)
add("ui_deny", ui_deny(), 0.6)


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
    parts, index, cur = [np.zeros(int(SR * GAP))], {}, GAP
    for name, (sig, gain, loop) in SOUNDS.items():
        sig = sig.astype(np.float64)
        if not loop:
            fade = min(len(sig), int(SR * 0.012))
            sig[-fade:] *= np.linspace(1, 0, fade)
        index[name] = (round(cur, 4), round(len(sig) / SR, 4), gain, loop)
        parts.append(sig)
        parts.append(np.zeros(int(SR * GAP)))
        cur += len(sig) / SR + GAP
    atlas = np.concatenate(parts)
    write_ogg(os.path.join(out_dir, "ZR_SFX_Env.ogg"), atlas)
    lines = ["--!strict", "-- GENERATED by assets/audio/synth_env.py: regions of the ZR_SFX_Env audio asset (seconds).",
             "-- name = { start, length, gain, loop } (loop regions are seamless; play them with Sound.LoopRegion)", "return {"]
    for name, (s0, ln, g, loop) in index.items():
        lines.append(f"\t{name} = {{ {s0}, {ln}, {g}, {'true' if loop else 'false'} }},")
    lines.append("}")
    with open(luau, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"env atlas {len(atlas) / SR:.2f}s, {len(index)} sounds")
