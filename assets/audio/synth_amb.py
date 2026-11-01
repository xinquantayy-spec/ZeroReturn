#!/usr/bin/env python3
"""Zero Return - procedural ambience atlas (atmosphere pass, original synthesis, no samples).
Loops: empty-mall room tone (sub rumble, air handling, wind whistling through broken skylights), mains + fluorescent
hum for powered halls, car park tone, the IRONSIGHT gun-shop alarm siren, the power-station generator.
One-shots: three water drips in a big hall, three far-off gunfire bursts with long echo tails, three breaking-glass sounds
(a bright crack, a spray of shards, pieces tinkling down).
Every loop repeats EXACTLY: noise is built in the frequency domain (random phases, so it is periodic in the loop
length), tones have a whole number of cycles per loop, and filters/reverbs are circular. No crossfade seam, so the
game can loop the region (Sound.LoopRegion) with no click.
Usage: python3 -I assets/audio/synth_amb.py <out_dir> <luau_out>
  -> <out_dir>/ZR_SFX_Amb.ogg  and  <luau_out> (AmbAtlas.luau: name -> {start, length, gain, loop})
"""
import sys, os, subprocess, wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(1101)
GAP = 0.12
TAU = 2 * np.pi


def T(sec):
    return np.arange(int(round(SR * sec))) / SR


def env(n, attack, decay):
    x = np.arange(n) / SR
    return np.clip(x / max(attack, 1e-4), 0, 1) * np.exp(-x / decay)


def bp(s, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), s)


def lp(s, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), s)


def hp(s, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), s)


def noise(sec):
    return rng.standard_normal(int(round(SR * sec)))


def norm(s, peak=0.9):
    return s / (np.max(np.abs(s)) + 1e-9) * peak


def at(base, s, t0, g=1.0):
    i = int(SR * t0)
    j = min(len(base), i + len(s))
    if i < len(base):
        base[i:j] += s[: j - i] * g
    return base


# ── frequency-domain tools (loop-safe) ───────────────────────────────────────────────────────────────────────
def sband(f, lo, hi, order=2):
    """Smooth band-pass magnitude (Butterworth-like corners at lo and hi)."""
    f = np.maximum(f, 1e-3)
    return 1.0 / np.sqrt(1 + (lo / f) ** (2 * order)) / np.sqrt(1 + (f / hi) ** (2 * order))


def gauss(f, fc, bw):
    return np.exp(-0.5 * ((f - fc) / bw) ** 2)


def fft_noise(n, shape):
    """Coloured noise that repeats exactly every n samples: magnitude shape(f), random phases, unit RMS."""
    f = np.fft.rfftfreq(n, 1 / SR)
    spec = shape(f) * np.exp(1j * rng.uniform(0, TAU, len(f)))
    spec[0] = 0
    if n % 2 == 0:
        spec[-1] = spec[-1].real
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def fshape(s, shape):
    """Circular filter: multiply the spectrum of a periodic signal by shape(f) (the result is still periodic)."""
    f = np.fft.rfftfreq(len(s), 1 / SR)
    return np.fft.irfft(np.fft.rfft(s) * shape(f), len(s))


def circ_reverb(s, length=1.5, decay=0.5, tone=3500, wet=0.3):
    """Room tail by circular convolution: the tail of one pass wraps into the next, so a loop stays seamless."""
    n = len(s)
    m = min(int(SR * length), n - 1)
    ir = rng.standard_normal(m) * np.exp(-np.arange(m) / SR / decay)
    ir = lp(ir, tone)
    ir /= np.sqrt(np.sum(ir**2)) + 1e-12
    pad = np.zeros(n)
    pad[:m] = ir
    wetsig = np.fft.irfft(np.fft.rfft(s) * np.fft.rfft(pad), n)
    return s * (1 - wet * 0.5) + wetsig * wet


def whole(freq, L):
    """Snap a frequency to a whole number of cycles per loop of L seconds."""
    return round(freq * L) / L


def loop_seam(s):
    """Curvature at the loop seam relative to the sharpest interior curvature (at most about 1 when the loop repeats exactly)."""
    d2 = np.abs(s[2:] - 2 * s[1:-1] + s[:-2])
    seam = max(abs(s[0] - 2 * s[-1] + s[-2]), abs(s[1] - 2 * s[0] + s[-1]))
    return seam / (np.max(d2) + 1e-12)


# ── loops ────────────────────────────────────────────────────────────────────────────────────────────────────
def room_tone_loop(L=12.0):
    """An empty mall: sub rumble of the building, air handling in the ducts, wind whistling through broken skylights."""
    n = int(SR * L)
    t = T(L)

    def sw(cycles, ph):
        return np.sin(TAU * cycles * t / L + ph)

    rumble = fft_noise(n, lambda f: sband(f, 34, 140, 3) * (60.0 / np.maximum(f, 20)) ** 0.5)
    rumble *= 1 + 0.16 * sw(2, 1.1) + 0.09 * sw(5, 0.4)
    body = fft_noise(n, lambda f: sband(f, 120, 480, 2)) * (0.7 + 0.2 * sw(2, 3.0))  # the room itself
    air = fft_noise(n, lambda f: sband(f, 220, 2600, 2))
    air *= 0.72 + 0.18 * sw(3, 2.0) + 0.1 * sw(7, 0.2)
    # blower tones in the ducts: close pairs beat slowly
    fan = np.zeros(n)
    for fr, a, ph in ((97.0, 1.0, 0.3), (98.5, 0.8, 2.2), (194.0, 0.35, 1.0), (291.5, 0.12, 4.1)):
        fan += a * np.sin(TAU * whole(fr, L) * t + ph)
    fan *= 0.55 + 0.25 * sw(1, 0.0)
    # gusts finding their way through the broken skylights: narrow whistles that drift and come and go
    whistle = np.zeros(n)
    for fc, bw, gc, gph, a in ((780, 14, 2, 0.3, 1.0), (1210, 18, 3, 1.9, 0.8), (1730, 24, 1, 4.0, 0.55), (2480, 36, 4, 0.8, 0.32)):
        gust = np.clip(sw(gc, gph), 0, 1) ** 2
        lo_n = fft_noise(n, lambda f, fc=fc, bw=bw: gauss(f, fc * 0.96, bw))
        hi_n = fft_noise(n, lambda f, fc=fc, bw=bw: gauss(f, fc * 1.04, bw))
        mixw = 0.5 + 0.5 * sw(gc + 2, gph + 1.3)
        whistle += a * gust * (lo_n * (1 - mixw) + hi_n * mixw)
    gust_hiss = fft_noise(n, lambda f: sband(f, 380, 1500, 2)) * np.clip(sw(2, 0.3), 0, 1) ** 2
    s = 0.55 * rumble + 0.45 * body + 0.8 * air + 0.16 * fan + 0.42 * whistle + 0.3 * gust_hiss
    return norm(s, 0.8)


def elec_hum_loop(L=8.0):
    """Powered halls: transformer/mains hum at 50 Hz and harmonics, the 100 Hz ballast buzz of fluorescent tubes."""
    t = T(L)
    n = len(t)
    s = np.zeros(n)
    mains = (0.5, 1.0, 0.8, 0.5, 0.45, 0.3, 0.25, 0.2, 0.14, 0.12, 0.08, 0.07)
    for k, a in enumerate(mains, 1):
        s += a * np.sin(TAU * 50 * k * t + rng.uniform(0, TAU))
    buzz = np.zeros(n)
    for k in range(1, 41):
        f = 100 * k
        a = 0.34 / k**0.5 * (1 if f < 2400 else np.exp(-(f - 2400) / 1500))
        buzz += a * np.sin(TAU * f * t + rng.uniform(0, TAU))
    # a lamp ballast singing high up, and the air of a quiet room
    sing = 0.035 * np.sin(TAU * whole(3120, L) * t) * (0.6 + 0.4 * np.sin(TAU * 3 * t / L))
    air = fft_noise(n, lambda f: sband(f, 2500, 9000, 2)) * 0.03
    s = (s * 0.42 + buzz * 1.0 + sing + air) * (1 + 0.04 * np.sin(TAU * 2 * t / L + 0.7))
    return norm(s, 0.8)


def garage_tone_loop(L=12.0):
    """Car park: a big concrete volume. Deep rumble, a hollow wash, a far-off ventilation fan with its blade-pass throb."""
    n = int(SR * L)
    t = T(L)

    def sw(cycles, ph):
        return np.sin(TAU * cycles * t / L + ph)

    rumble = fft_noise(n, lambda f: sband(f, 28, 120, 3) * (45.0 / np.maximum(f, 20)) ** 0.7)
    rumble *= 1 + 0.22 * sw(3, 0.5) + 0.1 * sw(4, 2.6)
    wash = fft_noise(n, lambda f: sband(f, 80, 950, 2) * (1 + 1.2 * gauss(f, 260, 70)))
    wash *= 0.65 + 0.2 * sw(2, 1.7) + 0.1 * sw(5, 3.3)
    fan = np.zeros(n)
    for fr, a, ph in ((46.0, 1.0, 0.2), (92.0, 0.5, 1.4), (138.5, 0.22, 3.0), (231.0, 0.1, 5.0)):
        fan += a * np.sin(TAU * whole(fr, L) * t + ph)
    fan *= 1 + 0.2 * np.sin(TAU * 7 * t)  # blade pass
    clarity = fft_noise(n, lambda f: sband(f, 1400, 4200, 2)) * 0.05
    s = 0.55 * rumble + 1.0 * wash + 0.3 * fan + clarity * 1.3
    s = fshape(s, lambda f: 1.0 / np.sqrt(1 + (f / 2600) ** 4))
    return norm(s, 0.8)


def siren_loop(L=3.2):
    """The IRONSIGHT store alarm: an electronic wail (two sweeps) from a horn speaker across a big hall."""
    n = int(SR * L)
    t = T(L)
    period = L / 2
    f = 880 + 300 * np.sin(TAU * t / period - np.pi / 2)  # 580 -> 1180 Hz -> 580
    ph = TAU * (np.cumsum(f) - f) / SR  # phase 0 at the first sample
    # close the phase so the loop meets itself: remove the fraction of a cycle left over at the end
    end = ph[-1] + TAU * f[-1] / SR
    ph -= (end - TAU * round(end / TAU)) * np.arange(n) / n
    tone = np.zeros(n)
    for k in range(1, 9):
        tone += np.sin(k * ph) / k**1.15
    tone *= 1 + 0.03 * np.sin(TAU * whole(8, L) * t)
    horn = fshape(tone, lambda x: sband(x, 430, 5200, 2) * (1 + 0.6 * gauss(x, 1900, 500)))
    horn = np.tanh(horn / (np.std(horn) + 1e-12) * 1.4)  # driven horn: soft clipping
    s = circ_reverb(horn, 1.8, 0.7, 3000, 0.34)
    return norm(s, 0.82)


def generator_loop(L=8.0):
    """The power-station generator: a slow diesel (25 firing pulses a second) hunting a little, exhaust putt and knock."""
    t = T(L)
    n = len(t)
    f0 = 25.0
    ph = TAU * (f0 * t + (f0 * 0.012 / (TAU * 0.25)) * (1 - np.cos(TAU * 0.25 * t)))  # +-1.2 % hunting, whole cycles
    pulses = int(round(f0 * L))
    amp = rng.uniform(0.82, 1.18, pulses)  # cylinder to cylinder unevenness (repeats with the loop)
    m = np.floor((ph + np.pi) / TAU).astype(int) % pulses
    pm = ((ph + np.pi) % TAU) - np.pi  # phase inside the pulse: -pi .. pi around the firing instant

    def pulse(width):
        return np.exp(-((pm / width) ** 2)) * amp[m]

    thump = pulse(1.0)
    putt = fshape(pulse(0.55), lambda f: sband(f, 55, 420, 2))
    chuff = fft_noise(n, lambda f: sband(f, 220, 1300, 2)) * pulse(0.7)  # exhaust
    knock = fft_noise(n, lambda f: sband(f, 900, 3400, 2)) * pulse(0.28)
    block = fft_noise(n, lambda f: gauss(f, 92, 14) + 0.7 * gauss(f, 141, 20) + 0.4 * gauss(f, 205, 24)) * (0.6 + 0.4 * thump)
    alt = 0.5 * np.sin(TAU * 50 * t + 0.4) + 0.3 * np.sin(TAU * 100 * t + 1.9) + 0.12 * np.sin(TAU * 150 * t)
    wind = fft_noise(n, lambda f: sband(f, 1800, 7000, 2)) * 0.05
    s = 0.42 * thump + 0.9 * putt + 1.1 * chuff + 0.6 * knock + 0.5 * block + 0.3 * alt + wind * 1.4
    s = fshape(s, lambda f: 1.0 / np.sqrt(1 + (f / 3800) ** 4))
    return norm(s, 0.82)


# ── one-shots ────────────────────────────────────────────────────────────────────────────────────────────────
def reverb(s, length=1.2, decay=0.35, tone=3000, wet=0.35):
    n = int(SR * length)
    ir = lp(rng.standard_normal(n) * np.exp(-np.arange(n) / SR / decay), tone)
    ir /= np.max(np.abs(ir)) + 1e-9
    c = np.convolve(s, ir)
    out = np.zeros(len(c))
    out[: len(s)] += s
    out += c / (np.max(np.abs(c)) + 1e-9) * np.max(np.abs(s)) * wet
    return out


def drip(v):
    """A drop falling into a puddle in a big hall: a rising bubble 'plink', a tiny splash tick, slap echoes and a tail."""
    L = 1.7
    s = np.zeros(int(SR * L))
    f_end = (1450, 1850, 2350)[v]
    m = int(SR * 0.14)
    x = np.arange(m) / SR
    f = f_end * 0.5 + f_end * 0.5 * (1 - np.exp(-x / 0.011))
    ph = TAU * np.cumsum(f) / SR
    ping = np.sin(ph) * env(m, 0.0008, 0.016)
    tick = hp(noise(0.03), 3200) * env(int(SR * 0.03), 0.0002, 0.0035) * 0.35
    drop = ping.copy()
    drop[: len(tick)] += tick
    s = at(s, drop, 0.01)
    for d, g in ((0.11 + 0.02 * v, 0.28), (0.23 + 0.03 * v, 0.17), (0.41 + 0.02 * v, 0.1), (0.63, 0.06)):
        s = at(s, lp(drop, 2600), d, g)
    s = reverb(s[: int(SR * 1.2)], 1.0, 0.45, 2400, 0.32)
    return norm(s, 0.85)


def gun_shot(f_lp=1000, body=68, n_sec=0.5):
    """One far-off report: no crack (it is far), a smeared noise burst and a low thump."""
    n = int(SR * n_sec)
    x = np.arange(n) / SR
    burst = bp(rng.standard_normal(n), 140, f_lp, 2) * env(n, 0.005, 0.07) * 2.2
    thump = np.sin(TAU * body * (1 + 0.7 * np.exp(-x / 0.05)) * x) * env(n, 0.008, 0.1) * 0.3
    return burst + thump


def far_echo(dry, tail, slaps, decay):
    """Buildings and hillsides answer: discrete slap echoes (darker as they get later) and a long diffuse tail."""
    n = len(dry)
    ir = np.zeros(int(SR * tail))
    ir[0] = 1.0
    for d, g in slaps:
        k = int(SR * d)
        if k < len(ir):
            cut = max(380, 1500 - 750 * d)
            one = np.zeros(int(SR * 0.12))
            one[0] = 1.0
            one = lp(one, cut)
            j = min(len(ir), k + len(one))
            ir[k:j] += one[: j - k] * g
    diffuse = lp(rng.standard_normal(len(ir)), 900) * np.exp(-np.arange(len(ir)) / SR / decay)
    diffuse[: int(SR * 0.18)] *= np.linspace(0, 1, int(SR * 0.18))
    ir += diffuse * 0.0045
    return fftconvolve(dry, ir)[: n]


def gun_far(v):
    L = 6.5
    n = int(SR * L)
    dry = np.zeros(n)
    if v == 0:  # a four-round burst
        for k in range(4):
            dry = at(dry, gun_shot(2000, 68), 0.2 + k * 0.088, 1.0 - 0.06 * k)
        slaps = ((0.46, 0.36), (0.93, 0.24), (1.62, 0.15), (2.4, 0.09))
    elif v == 1:  # one shot, then a short burst from a different weapon
        dry = at(dry, gun_shot(1600, 58), 0.2, 1.0)
        for k in range(3):
            dry = at(dry, gun_shot(2400, 84), 1.55 + k * 0.074, 0.8 - 0.05 * k)
        slaps = ((0.58, 0.34), (1.21, 0.2), (1.9, 0.13), (2.9, 0.07))
    else:  # a longer, ragged burst and a stray single shot
        t0 = 0.2
        for k in range(8):
            dry = at(dry, gun_shot(2100, 74), t0, 1.0 - 0.04 * k)
            t0 += 0.082 + rng.uniform(-0.012, 0.016)
        dry = at(dry, gun_shot(1700, 62), 2.35, 0.7)
        slaps = ((0.4, 0.38), (0.82, 0.27), (1.38, 0.17), (2.1, 0.11), (3.1, 0.06))
    s = far_echo(dry, 5.5, slaps, 1.5 + 0.2 * v)
    s = lp(s, 2600)  # air takes the top end
    s *= np.clip((L - np.arange(n) / SR) / 1.0, 0, 1)
    return norm(s, 0.85)


# ── atlas ────────────────────────────────────────────────────────────────────────────────────────────────────
SOUNDS = {}


# ── breakable glass (a pane shot out or smashed; Glass.luau / GlassFx.luau) ────────────────────────────────────
def glass_ping(f, length, decay, amp=1.0):
    """A sliver of glass ringing: a few inharmonic modes (a thin plate does not ring in whole-number ratios), dying fast."""
    n = max(8, int(SR * length))
    x = np.arange(n) / SR
    s = np.zeros(n)
    for ratio, a in ((1.0, 1.0), (2.32, 0.55), (4.19, 0.32), (6.7, 0.16)):
        fr = f * ratio
        if fr < 17000:
            s += a * np.sin(TAU * fr * x + rng.uniform(0, TAU))
    return s * env(n, 0.0004, decay) * amp


def glass_break(v):
    """A pane shot out: a bright crack, the sheet giving way in a spray of shards, then pieces tinkling down onto the floor.
    v = 0 a window, 1 a thick shopfront (lower, longer), 2 a small pane (quick)."""
    L = (2.2, 2.7, 1.8)[v]
    n = int(SR * L)
    s = np.zeros(n)
    # the crack: a hard broadband snap, brightest in the top octaves, and the short bell of the whole sheet
    m = int(SR * 0.05)
    s = at(s, hp(noise(0.05), 2200) * env(m, 0.0002, 0.005) * 1.5, 0.0, 1.0)
    s = at(s, lp(noise(0.05), 900) * env(m, 0.0005, 0.012) * 0.6, 0.0, 1.0)  # the thud of the sheet letting go of its frame
    for fr, a, dec in ((2300 + 400 * v, 0.7, 0.05), (3650 + 500 * v, 0.55, 0.04), (5200.0, 0.35, 0.03)):
        s = at(s, glass_ping(fr, 0.2, dec), 0.0, a)
    # the collapse: a dense spray of small pieces that thins out over about half a second
    gap = (0.0055, 0.0048, 0.0065)[v]
    t = 0.012
    while t < 0.55:
        s = at(s, glass_ping(rng.uniform(1800, 9500), 0.18, rng.uniform(0.012, 0.05)), t, rng.uniform(0.15, 0.6) * np.exp(-t / 0.2))
        t += rng.exponential(gap * (1 + 2.5 * t))
    # glass sliding off the frame: a short fall of filtered noise
    m = int(SR * 0.6)
    s = at(s, bp(noise(0.6), 3200, 9000) * env(m, 0.01, 0.12) * 0.22, 0.02, 1.0)
    # the tail: pieces tinkling onto the floor, further and further apart
    t = 0.38 + 0.05 * v
    while t < L - 0.25:
        s = at(s, glass_ping(rng.uniform(2600, 10500), 0.35, rng.uniform(0.04, 0.11)), t, rng.uniform(0.06, 0.28) * np.exp(-(t - 0.3) / 0.8))
        t += rng.exponential(0.045 + 0.09 * (t - 0.3))
    s = reverb(s, 1.0, 0.3, 4800, 0.22)[:n]
    return norm(s, 0.9)


def add(name, sig, gain=1.0, loop=False):
    SOUNDS[name] = (sig, gain, loop)


add("room_tone_loop", room_tone_loop(), 0.5, True)
add("elec_hum_loop", elec_hum_loop(), 0.35, True)
add("garage_tone_loop", garage_tone_loop(), 0.5, True)
add("siren_loop", siren_loop(), 0.9, True)
add("generator_loop", generator_loop(), 0.6, True)
for i in range(3):
    add(f"drip_{i + 1}", drip(i), 0.7)
for i in range(3):
    add(f"gun_far_{i + 1}", gun_far(i), 0.6)
# glass last: the regions above keep their start times (and the random draws that made them), so the asset already uploaded
# still plays every earlier region correctly; only the new glass regions lie past the end of the old asset
for i in range(3):
    add(f"glass_break_{i + 1}", glass_break(i), 0.9)


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
            # pad to a whole number of centiseconds so every region start is an exact time
            sig = np.concatenate([sig, np.zeros((-len(sig)) % (SR // 100))])
        else:
            # a loop must be a whole number of samples that lands on a 4-decimal time, or the region would drift
            assert abs(len(sig) / SR - round(len(sig) / SR, 4)) < 1e-9, name
            print(f"  {name}: seam curvature x{loop_seam(sig):.2f} of the sharpest interior curvature")
        index[name] = (round(cur, 4), round(len(sig) / SR, 4), gain, loop)
        parts.append(sig)
        parts.append(np.zeros(int(SR * GAP)))
        cur += len(sig) / SR + GAP
    atlas = np.concatenate(parts)
    path = os.path.join(out_dir, "ZR_SFX_Amb.ogg")
    write_ogg(path, atlas)
    lines = ["--!strict", "-- GENERATED by assets/audio/synth_amb.py: regions of the ZR_SFX_Amb audio asset (seconds).",
             "-- name = { start, length, gain, loop } (loop regions repeat exactly; play them with Sound.LoopRegion)", "return {"]
    for name, (s0, ln, g, loop) in index.items():
        lines.append(f"\t{name} = {{ {s0}, {ln}, {g}, {'true' if loop else 'false'} }},")
    lines.append("}")
    with open(luau, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"amb atlas {len(atlas) / SR:.2f}s, {len(index)} sounds, {os.path.getsize(path) / 1024:.0f} KB")
