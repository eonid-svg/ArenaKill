#!/usr/bin/env python3
"""Generate simple synth SFX + a music loop for ArenaKill (stdlib only).

Run:  python3 tools/generate_sounds.py
Outputs 16-bit mono WAVs into assets/sounds/.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(s * 32767))
        w.writeframes(bytes(frames))
    print("wrote", path)


def lowpass(samples, alpha):
    out = []
    prev = 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def envelope(i, n, attack=0.01, release=0.25):
    a = int(attack * SR)
    r = int(release * SR)
    if i < a:
        return i / max(a, 1)
    if n - i < r:
        return (n - i) / max(r, 1)
    return 1.0


def make_dash():
    n = int(0.22 * SR)
    raw = [random.uniform(-1.0, 1.0) for _ in range(n)]
    raw = lowpass(raw, 0.35)
    return [raw[i] * envelope(i, n, 0.05, 0.4) * 0.6 for i in range(n)]


def make_slam():
    n = int(0.45 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(i, n, 0.002, 0.5)
        boom = math.sin(2 * math.pi * 70 * t) + 0.4 * math.sin(2 * math.pi * 45 * t)
        noise = random.uniform(-1.0, 1.0) * 0.4
        out.append((boom * 0.8 + noise) * env * 0.8)
    return out


def make_jump():
    n = int(0.18 * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = 250 + 350 * (i / n)
        out.append(math.sin(2 * math.pi * f * t) * envelope(i, n, 0.01, 0.5) * 0.4)
    return out


def make_land():
    n = int(0.15 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(i, n, 0.002, 0.6)
        out.append((math.sin(2 * math.pi * 90 * t) * 0.6 + random.uniform(-1, 1) * 0.3) * env * 0.5)
    return out


def make_shoot():
    n = int(0.14 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(i, n, 0.001, 0.6)
        click = math.sin(2 * math.pi * 800 * t) * (1 - t / (n / SR))
        noise = random.uniform(-1.0, 1.0) * 0.5
        out.append((click * 0.5 + noise) * env * 0.7)
    return out


def make_hit():
    n = int(0.18 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(i, n, 0.001, 0.6)
        tone = math.sin(2 * math.pi * 320 * t) + 0.5 * math.sin(2 * math.pi * 640 * t)
        out.append((tone * 0.6 + random.uniform(-1, 1) * 0.2) * env * 0.6)
    return out


def make_music():
    dur = 8.0
    n = int(dur * SR)
    samples = [0.0] * n
    bpm = 120.0
    beat = 60.0 / bpm  # 0.5s
    # Bass pulse on A1 (55 Hz).
    for i in range(n):
        t = i / SR
        phase = (t % beat) / beat
        gate = 1.0 if phase < 0.5 else 0.35
        bass = (math.sin(2 * math.pi * 55 * t) + 0.3 * math.sin(2 * math.pi * 110 * t)) * gate * 0.5
        samples[i] += bass
    # Arpeggio: A minor (A3 C4 E4 A4).
    notes = [220.0, 261.63, 329.63, 440.0]
    step = beat
    for k in range(int(dur / step)):
        f = notes[k % len(notes)]
        start = int(k * step * SR)
        end = min(start + int(step * SR), n)
        for i in range(start, end):
            t = (i - start) / SR
            env = min(1.0, t * 25) * (1.0 - t / step)
            s = (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2 * t)) * env * 0.22
            samples[i] += s
    m = max(abs(s) for s in samples) or 1.0
    return [s / m * 0.75 for s in samples]


if __name__ == "__main__":
    write_wav("dash.wav", make_dash())
    write_wav("slam.wav", make_slam())
    write_wav("jump.wav", make_jump())
    write_wav("land.wav", make_land())
    write_wav("shoot.wav", make_shoot())
    write_wav("hit.wav", make_hit())
    write_wav("music.wav", make_music())
    print("done")
