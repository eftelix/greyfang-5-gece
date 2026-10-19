"""Greyfang: 5 GECE - procedural sound synthesis.

All game audio is generated here (no recorded samples). Output: assets/audio/*.wav
Mono, 16-bit, 22050 Hz. Re-run to regenerate:  python tools/gen_audio.py
These are replaceable placeholder-quality synthesized assets.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1987)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    # simple one-pole lowpass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff, passes=2):
    # FFT brickwall-ish lowpass (fast)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** (2 * passes))
    return np.fft.irfft(X, len(x))


def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = 1.0 / (1.0 + (f / hi) ** 4) * (1.0 - 1.0 / (1.0 + (f / max(lo, 1)) ** 4))
    return np.fft.irfft(X * m, len(x))


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(ai, 1)
    e[:ai] = np.linspace(0, 1, ai)
    if di > 0:
        e[ai:ai + di] = np.linspace(1, s, len(e[ai:ai + di]))
    if ri > 0:
        e[-ri:] = np.linspace(e[-ri] if ri < n else s, 0, ri)
    return e


def decay(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def loopify(x, fade=0.15):
    # crossfade tail into head for seamless loops
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def save(name, x, peak=0.9):
    x = norm(x, peak)
    # short fades remove clicks at the start/end of every sound
    f = min(int(0.006 * SR), len(x) // 4)
    if f > 0:
        x = x.copy()
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x)/SR:.2f}s")


def tone(freq, dur, kind="sine", phase_mod=None):
    t = t_axis(dur)
    if callable(freq):
        f = freq(t)
        ph = 2 * np.pi * np.cumsum(f) / SR
    else:
        ph = 2 * np.pi * freq * t
    if phase_mod is not None:
        ph = ph + phase_mod
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    return np.sin(ph)


def metal_hit(dur, base, partials=(1, 2.76, 5.4, 8.93, 13.3), rate=6.0, bright=1.0):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for i, p in enumerate(partials):
        x += np.sin(2 * np.pi * base * p * t + rng.uniform(0, 6)) * decay(len(t), rate * (1 + i * 0.6)) / (1 + i * 0.5 / bright)
    click = noise(0.02) * decay(int(0.02 * SR), 200)
    x[:len(click)] += click * 0.8
    return x


def add(*arrs):
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[:len(a)] += a
    return out


def place(buf, snd, at, gain=1.0):
    i = int(at * SR)
    j = min(len(buf), i + len(snd))
    if i < len(buf):
        buf[i:j] += snd[: j - i] * gain
    return buf


def vowel_babble(dur, pitch=110, speed=6.0, seed=0):
    """Formant-ish garbled speech (not intelligible on purpose: 'damaged tape')."""
    r = np.random.default_rng(seed)
    t = t_axis(dur)
    n = len(t)
    # glottal source: saw with jitter + intonation
    f0 = pitch * (1 + 0.12 * np.sin(2 * np.pi * 0.7 * t) + 0.05 * r.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    src = tone(lambda tt: f0, dur, "saw")
    formants = [(730, 1090), (270, 2290), (530, 1840), (300, 870), (660, 1700), (440, 1020)]
    seg = int(SR / speed)
    out = np.zeros(n)
    for s in range(0, n, seg):
        e = min(n, s + seg)
        f1, f2 = formants[r.integers(len(formants))]
        piece = src[s:e]
        if len(piece) < 64:
            continue
        y = bandpass(piece, f1 * 0.7, f1 * 1.3) + 0.6 * bandpass(piece, f2 * 0.8, f2 * 1.2)
        w = np.hanning(len(piece))
        # syllable gaps
        if r.random() < 0.18:
            w *= 0.05
        out[s:e] += y * w
    return out


os.makedirs(OUT, exist_ok=True)

# ---------------- ambience ----------------
d = 4.0
t = t_axis(d)
hum = 0.5 * np.sin(2 * np.pi * 50 * t) + 0.3 * np.sin(2 * np.pi * 100 * t) + 0.15 * np.sin(2 * np.pi * 150 * t) + 0.08 * np.sin(2 * np.pi * 250 * t)
hum *= 1 + 0.08 * np.sin(2 * np.pi * 0.5 * t)
hum += 0.05 * lp_fast(noise(d), 2000)
save("amb_hum", hum, 0.5)

d = 3.0
t = t_axis(d)
fan = lp_fast(noise(d), 900) * (1 + 0.35 * np.sin(2 * np.pi * 14 * t)) + 0.15 * np.sin(2 * np.pi * 28 * t)
save("amb_fan", fan, 0.6)

d = 8.0
t = t_axis(d)
drone = 0.5 * np.sin(2 * np.pi * 41 * t) + 0.4 * np.sin(2 * np.pi * 41.7 * t) + 0.25 * np.sin(2 * np.pi * 61.5 * t + np.sin(2 * np.pi * 0.25 * t))
drone += 0.25 * lp_fast(noise(d), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.125 * t))
save("amb_drone", drone, 0.6)

d = 6.0
t = t_axis(d)
vent = bandpass(noise(d), 200, 1400) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.33 * t))
save("amb_vent", vent, 0.5)

# ---------------- office ----------------
x = np.zeros(int(0.9 * SR))
x = place(x, metal_hit(0.9, 95, rate=5), 0.0)
x = place(x, lp_fast(noise(0.25), 1500) * decay(int(0.25 * SR), 15), 0.0, 1.2)
slide = lp_fast(noise(0.35), 700) * np.linspace(0.2, 1, int(0.35 * SR))
x2 = np.zeros(int(1.2 * SR))
x2 = place(x2, slide, 0.0, 0.8)
x2 = place(x2, x, 0.3)
save("door_close", x2)

slide = lp_fast(noise(0.6), 600) * np.linspace(1, 0.1, int(0.6 * SR))
x = np.zeros(int(0.9 * SR))
x = place(x, metal_hit(0.4, 140, rate=12), 0.0, 0.5)
x = place(x, slide, 0.05)
save("door_open", x, 0.7)

d = 1.0
t = t_axis(d)
buzz = 0.5 * np.sin(2 * np.pi * 100 * t) + 0.25 * np.sin(2 * np.pi * 200 * t) + 0.1 * np.sin(2 * np.pi * 300 * t)
buzz = lp_fast(buzz, 900)
save("light_buzz", buzz, 0.45)

# camera switch: soft electronic tick (no harsh noise)
d = 0.12
t = t_axis(d)
x = (np.sin(2 * np.pi * 1200 * t) * 0.6 + np.sin(2 * np.pi * 600 * t) * 0.4) * decay(len(t), 45)
x += 0.08 * lp_fast(noise(d), 2500) * decay(len(t), 60)
save("cam_switch", x, 0.45)

d = 0.6
t = t_axis(d)
# tablet up/down: smooth servo sweep + soft blip, almost no noise
env = np.sin(np.pi * t / d) ** 2
wh = tone(lambda tt: 220 + 260 * tt / d, d, "sine") * env * 0.7 + tone(lambda tt: 440 + 520 * tt / d, d, "sine") * env * 0.2
wh += 0.04 * lp_fast(noise(d), 1200) * env
wh = place(wh, np.sin(2 * np.pi * 880 * t_axis(0.08)) * decay(int(0.08 * SR), 40), d - 0.12, 0.4)
save("cam_up", wh, 0.45)
wh2 = tone(lambda tt: 480 - 260 * tt / d, d, "sine") * env * 0.7 + tone(lambda tt: 960 - 520 * tt / d, d, "sine") * env * 0.2
wh2 += 0.04 * lp_fast(noise(d), 1000) * env
save("cam_down", wh2, 0.4)

save("static", loopify(lp_fast(bandpass(noise(2.15), 300, 6000), 3500)), 0.35)

x = np.zeros(int(2.5 * SR))
for i in range(5):
    x = place(x, add(metal_hit(0.5, 70 + rng.uniform(-5, 5), rate=9) * 0.8, lp_fast(noise(0.3), 500) * decay(int(0.3 * SR), 12)), i * 0.42 + rng.uniform(0, 0.08), 1.0 - i * 0.05)
save("knock", x)

d = 3.5
t = t_axis(d)
pd = tone(lambda tt: 180 * np.exp(-tt * 1.4) + 20, d, "saw") * decay(len(t), 0.9)
pd = lp_fast(pd, 1200)
pd = place(pd, metal_hit(1.0, 60, rate=4), 0.0, 0.8)
save("power_down", pd)

# ---------------- footsteps & movement ----------------
step = lp_fast(noise(0.35), 220) * decay(int(0.35 * SR), 14) + 0.5 * metal_hit(0.35, 55, rate=14)
save("step_heavy", step, 0.85)
step = add(metal_hit(0.4, 210, rate=12, bright=2.0) * 0.6, lp_fast(noise(0.3), 600) * decay(int(0.3 * SR), 20))
save("step_metal", step, 0.8)
x = np.zeros(int(0.45 * SR))
x = place(x, metal_hit(0.2, 900, rate=40, bright=2) * 0.5 + bandpass(noise(0.2), 1000, 5000) * decay(int(0.2 * SR), 40), 0.0)
x = place(x, metal_hit(0.2, 850, rate=40, bright=2) * 0.4 + bandpass(noise(0.2), 1000, 5000) * decay(int(0.2 * SR), 40), 0.12)
save("step_hoof", x, 0.7)

run = np.zeros(int(3.2 * SR))
tt = 0.0
gap = 0.30
while tt < 3.0:
    s = add(metal_hit(0.18, 300 + rng.uniform(-40, 40), rate=30, bright=2) * 0.7, bandpass(noise(0.15), 300, 3000) * decay(int(0.15 * SR), 30))
    run = place(run, s, tt, 0.3 + 0.7 * tt / 3.0)
    tt += gap
    gap = max(0.13, gap * 0.92)
save("rook_run", run)

x = np.zeros(int(2.4 * SR))
for i in range(9):
    f = rng.uniform(300, 1300)
    x = place(x, metal_hit(0.8, f, rate=rng.uniform(5, 12), bright=1.5), rng.uniform(0, 1.6), rng.uniform(0.3, 1.0))
save("pots", x)
x = metal_hit(1.6, 410, partials=(1, 2.32, 4.25, 6.63, 9.38), rate=3.5, bright=2)
save("tray", x)

d = 1.2
t = t_axis(d)
cur = lp_fast(noise(d), 1400) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 3.1 * t))) * np.sin(np.pi * t / d)
save("curtain", cur, 0.6)

x = np.zeros(int(2.0 * SR))
x = place(x, metal_hit(1.6, 140, rate=2.5, bright=1.5), 0.0)
x = place(x, lp_fast(metal_hit(1.0, 88, rate=3), 900), 0.35, 0.6)
save("metal_distant", lp_fast(x, 2500), 0.6)

# ---------------- voices / laughs ----------------
# Grayson low laugh: pulsed vocal "huh huh huh"
d = 2.2
t = t_axis(d)
laugh = np.zeros_like(t)
for k in range(5):
    st = 0.15 + k * 0.33
    dur = 0.22
    seg = vowel_babble(dur, pitch=78 - k * 3, speed=3, seed=10 + k)
    seg *= np.hanning(len(seg))
    laugh = place(laugh, seg, st)
laugh = lp_fast(laugh, 1800) + 0.08 * lp_fast(noise(d), 400) * np.sin(np.pi * t / d)
save("laugh_grayson", laugh)

# Golden whisper: babble reversed + slowed
wh = vowel_babble(3.0, pitch=60, speed=4, seed=99)[::-1]
wh = wh * 0.7 + 0.3 * bandpass(noise(3.0), 2000, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.8 * t_axis(3.0)))
save("golden_whisper", wh, 0.7)

# tape voices (garbled, two speakers)
for name, pitch, seed in (("voice_selim", 105, 3), ("voice_hakan", 92, 7), ("voice_dila", 205, 11), ("voice_owner", 190, 21)):
    d = 6.0
    v = vowel_babble(d, pitch=pitch, speed=7, seed=seed)
    v = bandpass(v, 300, 3200)
    v *= 1 + 0.25 * np.sin(2 * np.pi * 0.37 * t_axis(d))  # wow & flutter-ish
    v += 0.12 * bandpass(noise(d), 3000, 9000)  # tape hiss
    save(name, loopify(v, 0.2), 0.6)

x = np.zeros(int(0.5 * SR))
x = place(x, metal_hit(0.2, 1500, rate=50) * 0.6, 0.0)
x = place(x, metal_hit(0.2, 1200, rate=50) * 0.5, 0.18)
x = place(x, lp_fast(noise(0.3), 3000) * 0.15, 0.2)
save("tape_click", x, 0.6)

d = 0.45
t = t_axis(d)
save("beep", np.sin(2 * np.pi * 1000 * t) * env_adsr(len(t), 0.01, 0.05, 0.8, 0.05), 0.5)

# ---------------- music ----------------
# Original Grayson melody in Hicaz makam (D Eb F# G A Bb C D)
def note_freq(semi_from_d4):
    return 293.66 * 2 ** (semi_from_d4 / 12)

hicaz = {"D": 0, "Eb": 1, "F#": 4, "G": 5, "A": 7, "Bb": 8, "C": 10, "D5": 12, "Eb5": 13, "F#5": 16, "C4": -2, "A3": -5}
melody = [("A", .5), ("Bb", .25), ("A", .25), ("G", .5), ("F#", .5), ("Eb", .5), ("F#", .25), ("G", .25), ("A", 1.0),
          ("A", .5), ("C", .25), ("Bb", .25), ("A", .5), ("G", .5), ("F#", .5), ("Eb", .5), ("D", 1.0),
          ("D", .5), ("Eb", .25), ("F#", .25), ("G", .5), ("A", .5), ("Bb", .5), ("A", .5), ("G", .5), ("F#", .5),
          ("Eb", .5), ("F#", .5), ("Eb", .5), ("D", .5), ("D", 1.5)]


def musicbox_note(f, dur):
    tt = t_axis(dur + 0.6)
    x = np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.0 * tt) + 0.2 * np.sin(2 * np.pi * f * 3.97 * tt)
    return x * decay(len(tt), 4.0)


beat = 0.42
total = sum(d for _, d in melody) * beat + 1.0
mb = np.zeros(int(total * SR))
pos = 0.0
for n, dd in melody:
    mb = place(mb, musicbox_note(note_freq(hicaz[n]) * 2, dd * beat), pos, 0.6)
    pos += dd * beat
mb *= 1 + 0.04 * np.sin(2 * np.pi * 5 * t_axis(total))
save("musicbox", mb, 0.6)

# Broken stage music: detuned organ loop with dropouts
total = sum(d for _, d in melody) * 0.36 + 0.5
st = np.zeros(int(total * SR))
pos = 0.0
for n, dd in melody:
    f = note_freq(hicaz[n]) * (1 + rng.uniform(-0.02, 0.02))
    nt = t_axis(dd * 0.36)
    s = (tone(f, dd * 0.36, "square") * 0.3 + tone(f * 0.5, dd * 0.36, "tri") * 0.5) * env_adsr(len(nt), 0.01, 0.05, 0.6, 0.05)
    if rng.random() < 0.12:
        s *= 0.1
    st = place(st, s, pos)
    pos += dd * 0.36
st = lp_fast(st, 1400) + 0.06 * bandpass(noise(total), 1500, 7000)
save("stage_music", st, 0.5)

# 6 AM chime: bells
x = np.zeros(int(6.0 * SR))
for i, f in enumerate((587.3, 440.0, 493.9, 293.7, 293.7, 493.9, 587.3, 440.0)):
    x = place(x, metal_hit(2.5, f / 2, partials=(1, 2.0, 2.4, 3.0, 4.2), rate=1.5, bright=1.5), i * 0.6)
save("chime6", x)

# ---------------- jumpscares ----------------
def scream(dur, f0, f1, rough, cutoff, seed, wobble=8.0):
    r = np.random.default_rng(seed)
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** 0.5 + 25 * np.sin(2 * np.pi * wobble * t)
    s = tone(lambda tt: f, dur, "saw") + 0.7 * tone(lambda tt: f * 1.49, dur, "saw") + 0.5 * tone(lambda tt: f * 0.51, dur, "square")
    s += rough * r.uniform(-1, 1, len(t))
    s = np.tanh(s * 2.5)
    s = lp_fast(s, cutoff)
    return s * env_adsr(len(t), 0.005, 0.1, 0.9, 0.25)


save("scream_grayson", scream(2.0, 120, 70, 0.9, 3500, 1, 6) + 0.4 * metal_hit(2.0, 60, rate=3))
save("scream_benny", scream(2.0, 380, 900, 0.8, 6000, 2, 14))
save("scream_brutus", scream(2.0, 220, 140, 1.4, 4000, 3, 22) + 0.5 * metal_hit(2.0, 410, partials=(1, 2.32, 4.25), rate=2))
save("scream_rook", scream(1.8, 900, 1400, 1.0, 7500, 4, 30))
g = scream(3.0, 60, 40, 2.0, 9000, 5, 3)
g = np.where(rng.random(len(g)) < 0.5, g, np.roll(g, 400))
g += 0.6 * bandpass(noise(3.0), 200, 9000)
save("scream_golden", g)

# clue found: soft low tone + paper
d = 1.2
t = t_axis(d)
cf = (np.sin(2 * np.pi * 146.8 * t) + 0.5 * np.sin(2 * np.pi * 220 * t)) * decay(len(t), 3)
cf = place(cf, bandpass(noise(0.3), 1500, 7000) * decay(int(0.3 * SR), 10), 0.0, 0.3)
save("clue_found", cf, 0.55)

d = 0.08
save("ui_click", metal_hit(d, 1800, rate=60) * 0.5, 0.4)

# heartbeat-ish breathing low thump for danger moments
x = np.zeros(int(1.0 * SR))
th = lp_fast(noise(0.12), 120) * decay(int(0.12 * SR), 25)
x = place(x, th, 0.0)
x = place(x, th * 0.7, 0.22)
save("thump", x, 0.8)
print("done")
