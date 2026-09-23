#!/usr/bin/env python3
"""Build the note samples the app plays: real recordings, one file per note.

Guitar: the University of Iowa Electronic Music Studios recordings of a
Raimundo 118 classical guitar (mf, mono), played one string at a time from
the open string up to fret 18 or 19. "Freely available ... for any
projects, without restrictions." https://theremin.music.uiowa.edu/MISguitar.html

Bass: Karoryfer Samples "Growlybass", a Squier Jazz Bass recorded direct,
sustained notes at f. CC0. https://github.com/sfzinstruments/karoryfer.growlybass
Recorded every third semitone; the notes between are the nearest recording
shifted by one semitone.

Notes beyond what was recorded (seven-string and drop tunings, the top
frets) are the nearest recording pitch-shifted by resampling.

Every note is checked against its expected pitch (the build fails on a
mismatch), tuned to within a few cents, trimmed to its attack, faded out and
loudness matched, then written as MP3 with an index the app reads:

  apps/fretboard_trainer/assets/audio/guitar/s<string>_<midi>.mp3
  apps/fretboard_trainer/assets/audio/bass/<midi>.mp3
  apps/fretboard_trainer/assets/audio/samples.json

Downloads are cached in packaging/audio/.cache (not committed).
Run with: uv run --with numpy --with scipy --with soundfile packaging/audio/make_samples.py
"""
import json
import math
import os
import re
import subprocess
import sys

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfiltfilt

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(HERE, "..", "..", "apps", "fretboard_trainer", "assets", "audio")

SR = 44100
LENGTH = 2.6        # seconds kept per note
FADE = 0.7          # fade-out at the end
TARGET_RMS_DB = -20 # loudness of the first 400 ms
PEAK_DB = -1

# Pitch range the app can ask for (all tuning presets, every fret).
GUITAR_RANGE = (33, 86)
BASS_RANGE = (21, 68)

IOWA = ("https://theremin.music.uiowa.edu/sound%20files/MIS/Piano_Other/guitar/"
        "Guitar.mf.{string}.{range}.mono.aif")
# String index (0 = low E) -> Iowa string name and the files covering it.
IOWA_FILES = {
    0: ("sulE", ["E2B2", "C3B3"]),
    1: ("sulA", ["A2B2", "C3B3", "C4E4"]),
    2: ("sulD", ["D3B3", "C4Ab4"]),
    3: ("sulG", ["G3B3", "C4B4", "C5Db5"]),
    4: ("sulB", ["B3", "C4B4", "C5Gb5"]),
    5: ("sul_E", ["E4B4", "C5B5"]),
}

GROWLY = ("https://raw.githubusercontent.com/sfzinstruments/karoryfer.growlybass/"
          "HEAD/sustain/{name}_f_rr1.wav")
# Karoryfer names run an octave above scientific pitch (their e2 is E1).
GROWLY_NAMES = ["db2", "e2", "gb2", "a2", "c3", "eb3", "gb3", "a3", "c4", "eb4",
                "gb4", "a4", "c5", "eb5"]

NAMES = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


def midi_of(name):
    m = re.fullmatch(r"([a-gA-G])(b|#)?(-?\d)", name)
    if not m:
        raise ValueError(name)
    pc = NAMES[m.group(1).lower()] + {"b": -1, "#": 1, None: 0}[m.group(2)]
    return (int(m.group(3)) + 1) * 12 + pc


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        print("  downloading", name)
        # curl rather than urllib: it uses the system certificate store.
        subprocess.run(["curl", "-sfL", "-o", path + ".part", url], check=True)
        os.replace(path + ".part", path)
    return path


def load(path, highpass=None):
    x, sr = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = math.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g)
    if highpass:
        # Room rumble below the lowest note; it also fools pitch detection.
        x = sosfiltfilt(butter(4, highpass, "highpass", fs=SR, output="sos"), x)
    return x


def measure_pitch(x, expected_midi):
    """Fundamental near `expected_midi` (within 2 semitones), in MIDI
    (fractional), and how clearly periodic the signal is (0..1)."""
    seg = x[int(0.08 * SR):int(0.48 * SR)]
    seg = seg - seg.mean()
    n = len(seg)
    spec = np.fft.rfft(seg, 2 * n)
    ac = np.fft.irfft(spec * np.conj(spec))[:n]
    ac /= ac[0] + 1e-12
    lo = int(SR / hz(expected_midi + 2))
    hi = int(SR / hz(expected_midi - 2)) + 1
    k = lo + int(np.argmax(ac[lo:hi]))
    k = min(max(k, 1), n - 2)
    # Parabolic interpolation for a sub-sample lag.
    a, b, c = ac[k - 1], ac[k], ac[k + 1]
    lag = k + 0.5 * (a - c) / (a - 2 * b + c) if a - 2 * b + c else k
    if not k - 1 <= lag <= k + 1:
        lag = k
    return 69 + 12 * math.log2(SR / lag / 440), float(b)


def shift(x, semitones):
    """Pitch shift by resampling (also changes length, as a string would)."""
    if abs(semitones) < 1e-4:
        return x
    ratio = 2 ** (semitones / 12)
    # Rational approximation of the resampling ratio.
    up, down = 1000, int(round(1000 * ratio))
    g = math.gcd(up, down)
    return resample_poly(x, up // g, down // g)


def candidates(x):
    """Sample offsets where the level jumps: plucks, but also clicks and
    handling noise between the notes."""
    hop = int(0.01 * SR)
    frames = len(x) // hop
    rms = np.sqrt(np.array([np.mean(x[i * hop:(i + 1) * hop] ** 2) for i in range(frames)]) + 1e-12)
    db = 20 * np.log10(rms / rms.max())
    rise = np.array([db[i] - db[max(0, i - 15):i].min() if i else 0 for i in range(frames)])
    out = []
    for i in range(1, frames - 1):
        if rise[i] > 10 and rise[i] >= rise[i - 1] and rise[i] >= rise[i + 1]:
            if out and i - out[-1] < 30:
                continue
            p = i
            while p > 0 and db[p - 1] < db[p] - 1:  # back to the attack
                p -= 1
            out.append(p)
    return [max(0, p * hop - int(0.005 * SR)) for p in out]


def segment(x, midis):
    """Start of each note in `midis`, played in that order: for each, the
    first level jump after the previous note whose pitch clearly matches it
    better than its neighbors."""
    starts = []
    after = 0
    cands = candidates(x)
    level = [np.sqrt(np.mean(x[c:c + int(0.3 * SR)] ** 2)) for c in cands]
    loudest = max(level)
    for midi in midis:
        for c, l in zip(cands, level):
            if c < after or l < loudest * 10 ** (-24 / 20):
                continue
            here = x[c:c + int(0.6 * SR)]
            got, k = measure_pitch(here, midi)
            if k > 0.8 and abs(got - midi) < 0.5:
                starts.append(c)
                after = c + int(1.0 * SR)
                break
        else:
            raise RuntimeError(f"no pluck found for MIDI {midi}")
    return starts


def finish(x):
    """Trim, fade, loudness match."""
    x = np.array(x[:int(LENGTH * SR)], dtype=np.float64)
    if len(x) < int(LENGTH * SR):
        x = np.pad(x, (0, int(LENGTH * SR) - len(x)))
    fin = int(0.003 * SR)
    x[:fin] *= np.linspace(0, 1, fin)
    fade = int(FADE * SR)
    x[-fade:] *= np.linspace(1, 0, fade) ** 2
    rms = np.sqrt(np.mean(x[:int(0.4 * SR)] ** 2)) + 1e-12
    x *= 10 ** (TARGET_RMS_DB / 20) / rms
    peak = np.abs(x).max()
    limit = 10 ** (PEAK_DB / 20)
    if peak > limit:
        x *= limit / peak
    return x


def tuned(x, expected, label):
    got, clarity = measure_pitch(x, expected)
    cents = (got - expected) * 100
    if abs(cents) > 60 or clarity < 0.3:
        raise RuntimeError(f"{label}: expected MIDI {expected}, measured {got:.2f} "
                           f"(clarity {clarity:.2f})")
    return shift(x, -cents / 100) if abs(cents) > 5 else x


def write(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, finish(x).astype(np.float32), SR, format="MP3",
             subtype="MPEG_LAYER_III")


def guitar():
    notes = {}  # (string, midi) -> signal
    for string, (name, ranges) in IOWA_FILES.items():
        for rng in ranges:
            m = re.fullmatch(r"([A-G]b?\d)([A-G]b?\d)?", rng)
            first = midi_of(m.group(1))
            last = midi_of(m.group(2)) if m.group(2) else first
            path = fetch(IOWA.format(string=name, range=rng), f"guitar_{name}_{rng}.aif")
            x = load(path, highpass=60)
            starts = segment(x, list(range(first, last + 1)))
            for midi, start in zip(range(first, last + 1), starts):
                seg = x[start:start + int((LENGTH + 0.5) * SR)]
                notes[(string, midi)] = tuned(seg, midi, f"guitar s{string} {rng} {midi}")
    lowest = min(m for s, m in notes if s == 0)
    highest = max(m for s, m in notes if s == 5)
    index = {}
    for (string, midi), x in notes.items():
        write(x, os.path.join(OUT, "guitar", f"s{string}_{midi}.mp3"))
        index.setdefault(str(string), []).append(midi)
    # Below the low E and above the high E's top recording.
    for midi in range(GUITAR_RANGE[0], lowest):
        write(shift(notes[(0, lowest)], midi - lowest), os.path.join(OUT, "guitar", f"s0_{midi}.mp3"))
        index["0"].append(midi)
    for midi in range(highest + 1, GUITAR_RANGE[1] + 1):
        write(shift(notes[(5, highest)], midi - highest), os.path.join(OUT, "guitar", f"s5_{midi}.mp3"))
        index["5"].append(midi)
    return {k: sorted(v) for k, v in sorted(index.items())}


def bass():
    recorded = {}
    for name in GROWLY_NAMES:
        midi = midi_of(name) - 12
        x = load(fetch(GROWLY.format(name=name), f"bass_{name}.wav"), highpass=20)
        # Karoryfer samples are already cut at the attack.
        start = max(0, int(np.argmax(np.abs(x) > 0.02 * np.abs(x).max())) - int(0.002 * SR))
        recorded[midi] = tuned(x[start:], midi, f"bass {name}")
    out = []
    for midi in range(BASS_RANGE[0], BASS_RANGE[1] + 1):
        src = min(recorded, key=lambda r: (abs(r - midi), r))
        write(shift(recorded[src], midi - src), os.path.join(OUT, "bass", f"{midi}.mp3"))
        out.append(midi)
    return out


def main():
    print("guitar")
    g = guitar()
    print("bass")
    b = bass()
    with open(os.path.join(OUT, "samples.json"), "w") as f:
        json.dump({"guitar": g, "bass": b}, f, indent=1)
        f.write("\n")
    count = sum(len(v) for v in g.values()) + len(b)
    size = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fns in os.walk(OUT) for fn in fns)
    print(f"wrote {count} samples, {size / 1e6:.1f} MB")


if __name__ == "__main__":
    sys.exit(main())
