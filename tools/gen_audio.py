"""Synthesizes the game's placeholder sound effects and music loops.

Usage:  python3 tools/gen_audio.py        (or: make audio)

Writes 16-bit mono WAV files to assets/sounds/ and assets/music/. Everything
is generated from simple waveforms, so there is nothing to download. Tweak a
recipe below and re-run to change a sound.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_DIR = os.path.join(ROOT, "assets", "sounds")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")


# --- Building blocks ---------------------------------------------------------

def n(seconds):
    return int(seconds * RATE)


def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < duty else -1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    raise ValueError(kind)


def tone(f0, dur, kind="square", f1=None, vol=0.5, attack=0.005, release=None, duty=0.5, vibrato=0.0, vib_rate=6.0):
    """A note sliding from f0 to f1 (exponentially), with an attack/decay envelope."""
    f1 = f0 if f1 is None else f1
    total = n(dur)
    release = dur * 0.8 if release is None else release
    out = []
    phase = 0.0
    for i in range(total):
        t = i / RATE
        k = i / max(total - 1, 1)
        f = f0 * (f1 / f0) ** k
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase += f / RATE
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if t > dur - release:
            env *= max(0.0, (dur - t) / release)
        out.append(osc(kind, phase, duty) * env * vol)
    return out


def noise(dur, vol=0.5, attack=0.002, cutoff=1.0, cutoff_end=None, seed=1):
    """Low-passed white noise; cutoff 0..1 (fraction kept per sample), may sweep."""
    rng = random.Random(seed)
    total = n(dur)
    cutoff_end = cutoff if cutoff_end is None else cutoff_end
    out = []
    y = 0.0
    for i in range(total):
        t = i / RATE
        k = i / max(total - 1, 1)
        a = cutoff + (cutoff_end - cutoff) * k
        y += a * (rng.uniform(-1, 1) - y)
        env = min(1.0, t / attack) * (1.0 - k) ** 1.5
        out.append(y * env * vol)
    return out


def mix(*parts, offsets=None):
    offsets = offsets or [0.0] * len(parts)
    length = max(n(o) + len(p) for p, o in zip(parts, offsets))
    out = [0.0] * length
    for p, o in zip(parts, offsets):
        start = n(o)
        for i, v in enumerate(p):
            out[start + i] += v
    return out


def seq(notes, kind="square", vol=0.4, gap=0.0, duty=0.5):
    """Plays (freq, duration) pairs one after another."""
    parts, offs, t = [], [], 0.0
    for f, d in notes:
        if f:
            parts.append(tone(f, d, kind, vol=vol, duty=duty, release=d * 0.5))
            offs.append(t)
        t += d + gap
    return mix(*parts, offsets=offs)


def note(name):
    """'A4' -> Hz. Accepts sharps as '#'."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


def write(path, samples, peak=0.9):
    top = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, peak / top)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print("wrote", os.path.relpath(path, ROOT), "%.2fs" % (len(samples) / RATE))


# --- Sound effects -------------------------------------------------------------

SFX = {
    # Carl
    "kick": lambda: mix(tone(160, 0.09, "sine", 55, vol=0.9), noise(0.06, 0.5, cutoff=0.5)),
    "kick_heavy": lambda: mix(tone(140, 0.18, "sine", 40, vol=1.0), noise(0.12, 0.7, cutoff=0.6, cutoff_end=0.1),
                              tone(90, 0.12, "square", 45, vol=0.25)),
    "jump": lambda: tone(260, 0.11, "square", 560, vol=0.22, duty=0.25),
    "dodge": lambda: noise(0.16, 0.5, attack=0.03, cutoff=0.05, cutoff_end=0.6, seed=4),
    "player_hurt": lambda: mix(tone(330, 0.2, "square", 110, vol=0.45, duty=0.3), noise(0.08, 0.4, cutoff=0.7)),
    # Donut
    "switch_mode": lambda: mix(tone(note("C6"), 0.09, "sine", vol=0.45), tone(note("G6"), 0.14, "sine", vol=0.45),
                               offsets=[0.0, 0.06]),
    "magic_missile": lambda: tone(900, 0.16, "sine", 1700, vol=0.5, vibrato=0.04, vib_rate=40),
    "magic_blast": lambda: mix(tone(300, 0.38, "saw", 1300, vol=0.3, vibrato=0.05, vib_rate=30),
                               tone(600, 0.38, "sine", 2400, vol=0.35), noise(0.3, 0.25, cutoff=0.3, seed=7)),
    # Impacts
    "hit": lambda: mix(noise(0.07, 0.7, cutoff=0.8, seed=2), tone(220, 0.07, "square", 120, vol=0.3)),
    "enemy_death": lambda: mix(tone(420, 0.32, "square", 70, vol=0.35, duty=0.4), noise(0.2, 0.35, cutoff=0.4, seed=9)),
    "explosion": lambda: mix(noise(0.7, 1.0, cutoff=0.9, cutoff_end=0.02, seed=11), tone(80, 0.5, "sine", 35, vol=0.9)),
    "crate_break": lambda: mix(*[noise(0.05, 0.6, cutoff=0.7, seed=20 + i) for i in range(4)],
                               offsets=[0.0, 0.04, 0.09, 0.15]),
    "switch_click": lambda: mix(tone(1400, 0.03, "square", vol=0.3), tone(900, 0.05, "square", vol=0.3), offsets=[0, 0.04]),
    "blorp": lambda: mix(tone(180, 0.09, "sine", 520, vol=0.5), tone(520, 0.1, "sine", 150, vol=0.5), offsets=[0, 0.08]),
    "acid": lambda: mix(*[tone(300 + 80 * i, 0.06, "sine", 600 + 80 * i, vol=0.25) for i in range(3)],
                        offsets=[0, 0.07, 0.13]),
    # Pickups and healing
    "potion_pickup": lambda: seq([(note("E5"), 0.06), (note("G5"), 0.06), (note("C6"), 0.1)], "square", 0.3, duty=0.25),
    "potion_drink": lambda: mix(*[tone(400 + 90 * i, 0.07, "sine", 700 + 90 * i, vol=0.35) for i in range(4)],
                                offsets=[0, 0.06, 0.12, 0.18]),
    "heal": lambda: seq([(note("C5"), 0.1), (note("E5"), 0.1), (note("G5"), 0.1), (note("C6"), 0.25)], "sine", 0.4),
    "chest": lambda: seq([(note("C5"), 0.08), (note("E5"), 0.08), (note("G5"), 0.08), (note("C6"), 0.3)], "square", 0.3, duty=0.25),
    # Bosses
    "boss_warning": lambda: seq([(880, 0.09), (0, 0.04), (880, 0.12)], "square", 0.35),
    "boss_roar": lambda: mix(tone(95, 0.9, "saw", 70, vol=0.6, vibrato=0.08, vib_rate=13),
                             noise(0.9, 0.4, attack=0.05, cutoff=0.15, seed=13)),
    "slam": lambda: mix(tone(60, 0.45, "sine", 30, vol=1.0), noise(0.45, 0.8, cutoff=0.4, cutoff_end=0.03, seed=14)),
    "charge": lambda: noise(0.35, 0.6, attack=0.1, cutoff=0.02, cutoff_end=0.3, seed=15),
    # UI and progression
    "menu_click": lambda: tone(1000, 0.035, "square", 1300, vol=0.25, duty=0.25),
    "door": lambda: noise(0.3, 0.45, attack=0.08, cutoff=0.04, cutoff_end=0.01, seed=16),
    "life_lost": lambda: tone(500, 0.6, "square", 90, vol=0.4, duty=0.35, vibrato=0.03),
    "achievement": lambda: seq([(note("G5"), 0.08), (note("C6"), 0.08), (note("E6"), 0.08), (note("G6"), 0.32)],
                               "square", 0.3, duty=0.25),
    "floor_complete": lambda: seq([(note("C5"), 0.12), (note("C5"), 0.12), (note("C5"), 0.12), (note("C5"), 0.3),
                                   (note("G#4"), 0.3), (note("A#4"), 0.3), (note("C5"), 0.2), (0, 0.08), (note("A#4"), 0.12),
                                   (note("C5"), 0.6)], "square", 0.3, duty=0.25),
    "game_over": lambda: seq([(note("G4"), 0.3), (note("D#4"), 0.3), (note("C4"), 0.3), (note("G3"), 0.8)], "tri", 0.6),
}


# --- Music -----------------------------------------------------------------------

def track(bpm, chords, scale, seed, lead_kind="square", lead_duty=0.25, drums=True, bass_eighths=False,
          lead_vol=0.13, bass_vol=0.32, bars_per_chord=1):
    """A loop: triangle bass on chord roots, a square lead wandering over chord
    and scale tones, and noise/sine drums. Exactly loopable."""
    rng = random.Random(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = n(bar * len(chords) * bars_per_chord)
    out = [0.0] * total

    def add(samples, at):
        start = n(at)
        for i, v in enumerate(samples):
            if start + i < total:
                out[start + i] += v

    t = 0.0
    for chord in chords:
        root, tones = chord
        for _ in range(bars_per_chord):
            # Bass.
            step = beat / 2 if bass_eighths else beat
            for i in range(int(round(bar / step))):
                f = note(root) / 2 if i % 4 != 2 else note(root)
                add(tone(f, step * 0.9, "tri", vol=bass_vol, release=step * 0.3), t + i * step)
            # Lead: eighth notes, some rests, mostly chord tones.
            for i in range(8):
                if rng.random() < 0.3:
                    continue
                pool = tones if rng.random() < 0.7 else scale
                f = note(rng.choice(pool))
                length = beat / 2 * (2 if rng.random() < 0.25 else 1)
                add(tone(f, length * 0.9, lead_kind, vol=lead_vol, duty=lead_duty, release=length * 0.5), t + i * beat / 2)
            # Drums.
            if drums:
                for i in range(4):
                    if i % 2 == 0:
                        add(tone(110, 0.12, "sine", 45, vol=0.45), t + i * beat)
                    else:
                        add(noise(0.1, 0.28, cutoff=0.6, seed=rng.randint(0, 999)), t + i * beat)
                    add(noise(0.03, 0.08, cutoff=0.95, seed=rng.randint(0, 999)), t + i * beat + beat / 2)
            t += bar
    return out


A_MINOR = ["A4", "B4", "C5", "D5", "E5", "F5", "G5", "A5"]
D_MINOR = ["D4", "E4", "F4", "G4", "A4", "A#4", "C5", "D5"]
E_MINOR = ["E4", "F#4", "G4", "A4", "B4", "C5", "D5", "E5"]
C_MAJOR = ["C5", "D5", "E5", "G5", "A5", "C6"]

MUSIC = {
    "menu": lambda: track(84, [("C3", ["C5", "E5", "G5"]), ("A2", ["A4", "C5", "E5"]),
                               ("F2", ["F4", "A4", "C5"]), ("G2", ["G4", "B4", "D5"])] * 2,
                          C_MAJOR, seed=3, lead_kind="tri", lead_vol=0.22, drums=False),
    "floor1": lambda: track(108, [("A2", ["A4", "C5", "E5"]), ("F2", ["F4", "A4", "C5"]),
                                  ("C3", ["C5", "E5", "G5"]), ("G2", ["G4", "B4", "D5"])] * 2,
                            A_MINOR, seed=11),
    "floor2": lambda: track(100, [("D3", ["D4", "F4", "A4"]), ("A#2", ["A#4", "D5", "F5"]),
                                  ("F2", ["F4", "A4", "C5"]), ("A2", ["A4", "C#5", "E5"])] * 2,
                            D_MINOR, seed=22, lead_duty=0.5),
    "boss": lambda: track(150, [("E2", ["E4", "G4", "B4"]), ("E2", ["E4", "G4", "B4"]),
                                ("C3", ["C5", "E5", "G5"]), ("D3", ["D5", "F#5", "A5"])] * 2,
                          E_MINOR, seed=33, bass_eighths=True, lead_vol=0.12),
}


if __name__ == "__main__":
    for name, make in SFX.items():
        write(os.path.join(SFX_DIR, name + ".wav"), make())
    for name, make in MUSIC.items():
        write(os.path.join(MUSIC_DIR, name + ".wav"), make(), peak=0.7)
