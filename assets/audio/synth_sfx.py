#!/usr/bin/env python3
"""Zero Return - original procedural sound effects (no samples, no third-party audio).
Usage: python3 assets/audio/synth_sfx.py <out_dir>   -> writes ZR_SFX_*.ogg (mono, 44.1 kHz)
Design: layered transients + filtered noise + pitch-dropping thump + synthetic room/outdoor tails.
"""
import sys, os, subprocess, numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(1707)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, decay):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def bp(sig, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), sig)


def lp(sig, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), sig)


def hp(sig, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), sig)


def tail(sig, length, decay, tone=2500, wet=0.35):
    """Cheap synthetic reverb: convolve with exponentially decaying filtered noise."""
    ir_n = int(SR * length)
    ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR / decay)
    ir = lp(ir, tone)
    ir /= np.max(np.abs(ir)) + 1e-9
    conv = np.convolve(sig, ir) * 0.04
    out = np.zeros(len(sig) + ir_n)
    wetsig = np.zeros(len(out))
    wetsig[: len(conv)] = conv[: len(out)]
    out[: len(sig)] += sig
    return out + wetsig * wet / (np.max(np.abs(wetsig)) + 1e-9) * np.max(np.abs(sig))


def norm(sig, peak=0.92):
    return sig / (np.max(np.abs(sig)) + 1e-9) * peak


def pad(sig, total):
    out = np.zeros(int(SR * total))
    out[: min(len(sig), len(out))] = sig[: len(out)]
    return out


def gunshot(far=False):
    n = int(SR * 0.45)
    crack = hp(rng.standard_normal(n), 1800) * env(n, 0.0005, 0.012)
    body = bp(rng.standard_normal(n), 300, 4200) * env(n, 0.001, 0.05)
    x = t(0.45)
    f = 95 * np.exp(-x * 9) + 42
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.002, 0.09)
    mech = bp(rng.standard_normal(n), 2500, 7000) * env(n, 0.0003, 0.006)
    mech = np.roll(mech, int(SR * 0.035)) * 0.25
    sig = crack * 0.9 + body * 0.8 + thump * 1.1 + mech
    if far:
        sig = lp(sig, 1100) * 0.8
        return norm(tail(sig, 1.6, 0.55, tone=900, wet=0.9), 0.7)
    return norm(tail(sig, 0.9, 0.22, tone=3000, wet=0.45))


def click(freq=3200, length=0.04, noise=0.6):
    n = int(SR * length)
    x = t(length)
    s = np.sin(2 * np.pi * freq * x) * env(n, 0.0003, 0.006) + noise * hp(rng.standard_normal(n), 2000) * env(n, 0.0002, 0.004)
    return s


def reload_seq():
    seq = np.zeros(int(SR * 2.1))
    def put(at, s, g=1.0):
        i = int(SR * at)
        seq[i:i + len(s)] += s[: len(seq) - i] * g
    put(0.22, click(1900, 0.06, 0.8), 0.9)        # mag release
    put(0.30, bp(rng.standard_normal(int(SR * 0.12)), 400, 2500) * env(int(SR * 0.12), 0.002, 0.03), 0.7)  # mag slides out
    put(1.15, click(1400, 0.08, 1.0), 1.0)        # mag seats
    put(1.18, lp(rng.standard_normal(int(SR * 0.08)), 900) * env(int(SR * 0.08), 0.001, 0.02), 1.2)  # thud
    put(1.70, click(2600, 0.05, 0.9), 0.9)        # bolt back
    put(1.82, click(2200, 0.06, 1.1), 1.0)        # bolt forward
    return norm(tail(seq, 0.25, 0.05, tone=5000, wet=0.2), 0.8)


def hit_tick():
    return norm(click(1700, 0.05, 0.25) + 0.4 * click(900, 0.05, 0.0), 0.6)


def beep():
    x = t(0.14)
    tone = np.sin(2 * np.pi * 880 * x) * env(len(x), 0.004, 0.08)
    return norm(np.concatenate([tone, np.zeros(int(SR * 0.08)), tone * 0.9]), 0.5)


def ui_click():
    return norm(click(2400, 0.03, 0.3), 0.4)


def write(path, sig):
    wav = path[:-4] + ".wav"
    data = (np.clip(sig, -1, 1) * 32767).astype(np.int16)
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(wav)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sfx = {
        "ZR_SFX_R17_Fire": gunshot(False),
        "ZR_SFX_R17_FireFar": gunshot(True),
        "ZR_SFX_DryFire": norm(click(3600, 0.05, 0.5), 0.5),
        "ZR_SFX_Reload": reload_seq(),
        "ZR_SFX_HitTick": hit_tick(),
        "ZR_SFX_ExtractBeep": beep(),
    }
    for name, sig in sfx.items():
        write(os.path.join(out, name + ".ogg"), sig)
        print(name, f"{len(sig) / SR:.2f}s")
