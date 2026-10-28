#!/usr/bin/env python3
"""Zero Return - procedural combat sound atlas (M11, original synthesis, no samples).
Grenades (pin, lever, throw, bounces, explosions near/far, debris, stun bang, smoke pop and hiss), tinnitus,
weapon malfunctions (misfire click, clearing a stoppage, a jam) and the gunsmith repair kit.
Loops (smoke hiss, tinnitus) are seamless: the game loops their region (Sound.LoopRegion).
Usage: python3 assets/audio/synth_combat.py <out_dir> <luau_out>
  -> <out_dir>/ZR_SFX_Combat.ogg  and  <luau_out> (CombatAtlas.luau: name -> {start, length, gain, loop})
"""
import sys, os, subprocess, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(1111)
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


def ring(freqs, length, dec, amp=1.0):
    """struck metal: a few inharmonic partials with their own decays"""
    n = int(SR * length)
    x = T(length)
    s = np.zeros(n)
    for k, f in enumerate(freqs):
        s += np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) * np.exp(-x / (dec / (1 + 0.6 * k))) / (1 + k * 0.5)
    return s * amp


def reverb(s, length=1.2, decay=0.35, tone=3000, wet=0.35):
    n = int(SR * length)
    ir = lp(rng.standard_normal(n) * np.exp(-np.arange(n) / SR / decay), tone)
    ir /= np.max(np.abs(ir)) + 1e-9
    c = np.convolve(s, ir)
    out = np.zeros(len(c))
    out[: len(s)] += s
    out += c / (np.max(np.abs(c)) + 1e-9) * np.max(np.abs(s)) * wet
    return out


def seamless(s, xfade=0.5):
    n = int(SR * xfade)
    head, tail = s[:n].copy(), s[-n:].copy()
    k = np.linspace(0, 1, n)
    out = s[:-n].copy()
    out[:n] = head * np.sqrt(k) + tail * np.sqrt(1 - k)
    return out


# ── grenade handling ─────────────────────────────────────────────────────────
def nade_pin():
    """ring pin pulled: a short metal scrape, the split pin springing free, the ring tinkling"""
    s = np.zeros(int(SR * 0.42))
    m = int(SR * 0.09)
    s = at(s, bp(rng.standard_normal(m), 2500, 8000) * bell(m, 0.5, 0.35), 0.02, 0.5)
    s = at(s, click(3200, 0.05, 0.8, 0.008), 0.1, 0.9)
    s = at(s, ring((4100, 6300, 8800), 0.3, 0.05, 0.35), 0.12)
    s = at(s, ring((5200, 7900), 0.2, 0.03, 0.2), 0.2)
    return norm(s, 0.7)


def nade_spoon():
    """the lever flies off: a spring ping and a light tumble"""
    s = np.zeros(int(SR * 0.35))
    s = at(s, click(2400, 0.04, 1.0, 0.006), 0.0, 0.8)
    s = at(s, ring((2900, 4700, 6100), 0.25, 0.06, 0.4), 0.01)
    s = at(s, click(5200, 0.03, 0.7, 0.004), 0.17, 0.3)
    return norm(s, 0.6)


def nade_throw():
    """arm swing and cloth: a soft whoosh"""
    L = 0.45
    n = int(SR * L)
    s = bp(rng.standard_normal(n), 300, 2500) * bell(n, 0.45, 0.22) * 0.8
    s += lp(rng.standard_normal(n), 400) * bell(n, 0.3, 0.3) * 0.5
    return norm(s, 0.6)


def nade_bounce(v):
    """a cast-steel body hitting concrete: dull knock plus a short metallic ring"""
    s = np.zeros(int(SR * 0.3))
    s = at(s, lp(rng.standard_normal(int(SR * 0.05)), 900) * env(int(SR * 0.05), 0.0005, 0.012), 0.0, 1.0)
    base = (1450, 2350, 3550) if v == 0 else ((1650, 2700, 4100) if v == 1 else (1250, 2050, 3250))
    s = at(s, ring(base, 0.25, 0.035, 0.45), 0.002)
    s = at(s, click(rng.uniform(900, 1300), 0.03, 0.8, 0.006), 0.0, 0.6)
    return norm(s, 0.65)


# ── explosions ───────────────────────────────────────────────────────────────
def explosion_near():
    """close blast: a hard crack, a heavy low thump, the pressure wave and a reverberant tail"""
    L = 3.2
    n = int(SR * L)
    x = T(L)
    s = np.zeros(n)
    crack = hp(rng.standard_normal(int(SR * 0.06)), 1200) * env(int(SR * 0.06), 0.0002, 0.012)
    s = at(s, crack, 0.0, 1.0)
    thump = np.sin(2 * np.pi * (52 + 30 * np.exp(-x / 0.05)) * x) * env(n, 0.001, 0.22)
    s += thump * 1.4
    body = lp(rng.standard_normal(n), 700) * env(n, 0.002, 0.35)
    s += body * 1.1
    rumble = lp(rng.standard_normal(n), 160) * env(n, 0.05, 1.1)
    s += rumble * 0.9
    s = reverb(s, 1.8, 0.7, 1500, 0.45)[:n]
    s = np.tanh(s * 1.6)
    return norm(s, 0.98)


def explosion_far():
    """the same blast heard far away: no crack, a low boom rolling off the buildings"""
    L = 3.6
    n = int(SR * L)
    x = T(L)
    s = np.sin(2 * np.pi * (44 + 12 * np.exp(-x / 0.1)) * x) * env(n, 0.01, 0.4) * 1.2
    s += lp(rng.standard_normal(n), 220) * env(n, 0.02, 0.9)
    for k in range(3):
        echo = lp(rng.standard_normal(int(SR * 0.8)), 180) * bell(int(SR * 0.8), 0.25, 0.3)
        s = at(s, echo, 0.35 + k * rng.uniform(0.35, 0.6), 0.45 / (k + 1))
    s = reverb(lp(s, 600), 2.0, 0.9, 500, 0.5)[:n]
    return norm(s, 0.9)


def explosion_debris():
    """gravel, glass and metal raining down after a blast"""
    L = 1.9
    s = np.zeros(int(SR * L))
    k = 0.05
    while k < L - 0.15:
        f = rng.uniform(900, 5200)
        s = at(s, click(f, 0.05, rng.uniform(0.4, 1.0), rng.uniform(0.004, 0.012)), k, rng.uniform(0.1, 0.5) * np.exp(-k / 0.9))
        k += rng.exponential(0.035)
    s += bp(rng.standard_normal(len(s)), 600, 3000) * env(len(s), 0.01, 0.5) * 0.15
    return norm(s, 0.6)


def flashbang():
    """stun charge: an extremely sharp bang with a bright metallic edge"""
    L = 1.6
    n = int(SR * L)
    x = T(L)
    s = hp(rng.standard_normal(n), 900) * env(n, 0.0002, 0.03) * 1.5
    s += np.sin(2 * np.pi * (90 + 60 * np.exp(-x / 0.03)) * x) * env(n, 0.0005, 0.12)
    s += bp(rng.standard_normal(n), 2500, 9000) * env(n, 0.001, 0.08) * 0.6
    s = reverb(s, 1.3, 0.45, 4000, 0.35)[:n]
    return norm(np.tanh(s * 2.0), 0.98)


def smoke_pop():
    """the smoke fuse pops and the canister starts to hiss"""
    L = 0.9
    n = int(SR * L)
    s = np.zeros(n)
    s = at(s, lp(rng.standard_normal(int(SR * 0.08)), 1200) * env(int(SR * 0.08), 0.0005, 0.02), 0.0, 1.0)
    hiss = hp(rng.standard_normal(n), 1800) * np.clip(T(L) / 0.25, 0, 1) * 0.35
    s += hiss
    return norm(s, 0.7)


def smoke_hiss_loop():
    """steady burning hiss of a smoke canister (loop)"""
    L = 3.4
    n = int(SR * L)
    s = hp(rng.standard_normal(n), 1500) * 0.6 + bp(rng.standard_normal(n), 600, 1800) * 0.25
    s *= 1 + 0.12 * np.sin(2 * np.pi * T(L) / L * 5) + 0.05 * np.sin(2 * np.pi * T(L) / L * 13)
    return norm(seamless(s, 0.6), 0.6)


def tinnitus_loop():
    """ringing ears after a blast: a high tone with a slow beat and a bed of hiss (loop)"""
    L = 3.0
    x = T(L)
    f = 3520
    s = np.sin(2 * np.pi * f * x) * 0.6 + np.sin(2 * np.pi * (f + 3) * x) * 0.4  # 3 Hz beat (whole cycles in 3 s)
    s += bp(rng.standard_normal(len(x)), 3000, 4200) * 0.05
    return norm(seamless(s, 0.3), 0.5)


# ── weapon malfunctions and maintenance ──────────────────────────────────────
def malf_click():
    """misfire: the hammer falls, nothing happens"""
    s = np.zeros(int(SR * 0.25))
    s = at(s, click(1900, 0.05, 1.0, 0.007), 0.0, 1.0)
    s = at(s, lp(click(700, 0.06, 0.5, 0.012), 2500), 0.004, 0.5)
    return norm(s, 0.65)


def malf_clear():
    """clearing a stoppage: tilt, rack the action back hard, the round ejects, forward"""
    s = np.zeros(int(SR * 0.8))
    m = int(SR * 0.1)
    s = at(s, bp(rng.standard_normal(m), 400, 2500) * bell(m, 0.5, 0.3), 0.0, 0.3)
    s = at(s, click(1300, 0.06, 1.0, 0.012), 0.22, 1.0)
    m = int(SR * 0.08)
    s = at(s, bp(rng.standard_normal(m), 2000, 6000) * bell(m, 0.5, 0.3), 0.25, 0.5)
    s = at(s, ring((2600, 4300), 0.2, 0.04, 0.35), 0.32)  # cartridge tinkling away
    s = at(s, click(1100, 0.07, 1.0, 0.015), 0.52, 1.0)
    return norm(s, 0.75)


def malf_jam():
    """a hard jam: the bolt will not move, two hard pulls, then it frees"""
    s = np.zeros(int(SR * 1.5))
    for k, t0 in enumerate((0.1, 0.45)):
        m = int(SR * 0.12)
        s = at(s, lp(rng.standard_normal(m), 800) * bell(m, 0.4, 0.3), t0, 0.6)
        s = at(s, click(900, 0.05, 0.8, 0.01), t0 + 0.06, 0.7)
    s = at(s, click(1400, 0.07, 1.0, 0.012), 0.85, 1.0)
    s = at(s, ring((2500, 4100), 0.25, 0.05, 0.35), 0.9)
    s = at(s, click(1150, 0.07, 1.0, 0.015), 1.15, 1.0)
    return norm(s, 0.75)


def repair_kit():
    """gunsmith work: a ratchet, a brush, pins tapped home"""
    s = np.zeros(int(SR * 1.7))
    for k in range(9):
        s = at(s, click(rng.uniform(2200, 3000), 0.03, 0.9, 0.004), 0.05 + k * 0.045, 0.6)
    m = int(SR * 0.4)
    s = at(s, bp(rng.standard_normal(m), 1500, 7000) * bell(m, 0.5, 0.35), 0.55, 0.4)
    for k in range(3):
        s = at(s, ring((1800 + k * 200, 3100 + k * 300), 0.2, 0.04, 0.6), 1.05 + k * 0.18)
    return norm(s, 0.7)


SOUNDS = {}


def add(name, sig, gain=1.0, loop=False):
    SOUNDS[name] = (sig, gain, loop)


add("nade_pin", nade_pin(), 0.8)
add("nade_spoon", nade_spoon(), 0.7)
add("nade_throw", nade_throw(), 0.7)
add("nade_bounce_1", nade_bounce(0), 0.9)
add("nade_bounce_2", nade_bounce(1), 0.9)
add("nade_bounce_3", nade_bounce(2), 0.9)
add("explosion_near", explosion_near(), 1.0)
add("explosion_far", explosion_far(), 1.0)
add("explosion_debris", explosion_debris(), 0.8)
add("flashbang", flashbang(), 1.0)
add("smoke_pop", smoke_pop(), 0.8)
add("smoke_hiss_loop", smoke_hiss_loop(), 0.7, True)
add("tinnitus_loop", tinnitus_loop(), 0.5, True)
add("malf_click", malf_click(), 0.8)
add("malf_clear", malf_clear(), 0.8)
add("malf_jam", malf_jam(), 0.8)
add("repair_kit", repair_kit(), 0.7)


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
    write_ogg(os.path.join(out_dir, "ZR_SFX_Combat.ogg"), atlas)
    lines = ["--!strict", "-- GENERATED by assets/audio/synth_combat.py: regions of the ZR_SFX_Combat audio asset (seconds).",
             "-- name = { start, length, gain, loop } (loop regions are seamless; play them with Sound.LoopRegion)", "return {"]
    for name, (s0, ln, g, loop) in index.items():
        lines.append(f"\t{name} = {{ {s0}, {ln}, {g}, {'true' if loop else 'false'} }},")
    lines.append("}")
    with open(luau, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"combat atlas {len(atlas) / SR:.2f}s, {len(index)} sounds")
