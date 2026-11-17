#!/usr/bin/env python3
"""Placeholder liquid sounds: assets/sfx/splash.wav (into or out of water) and
assets/sfx/sizzle.wav (lava), synthesised so the effects have something to play.
Drop your own recordings over them (mono or stereo WAV, any rate) any time.

    python3 tools/make_liquid_sfx.py
"""
import math
import os
import random
import wave

import numpy as np

RATE = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sfx")


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def chirp(t: np.ndarray, f0: float, f1: float, length: float) -> np.ndarray:
    """A sine sliding from f0 to f1 over `length` seconds, then fading out."""
    f = f0 + (f1 - f0) * np.clip(t / length, 0, 1)
    phase = 2 * math.pi * np.cumsum(f) / RATE
    env = np.clip(1 - t / length, 0, 1) ** 2
    return np.sin(phase) * env


def place(buf: np.ndarray, snd: np.ndarray, at: float, gain: float) -> None:
    i = int(at * RATE)
    n = min(len(snd), len(buf) - i)
    if n > 0:
        buf[i:i + n] += snd[:n] * gain


def splash(rng: random.Random) -> np.ndarray:
    n = int(0.55 * RATE)
    t = np.arange(n) / RATE
    noise = np.array([rng.uniform(-1, 1) for _ in range(n)])
    body = lowpass(noise, 1800) * np.exp(-t / 0.09) * np.clip(t / 0.004, 0, 1)
    hiss = highpass(noise, 3000) * np.exp(-t / 0.05) * 0.35
    out = body * 1.6 + hiss
    tt = np.arange(int(0.12 * RATE)) / RATE
    place(out, chirp(tt, 260, 520, 0.12), 0.0, 0.55)          # the plunk: a bubble's rising note
    for _ in range(7):                                         # droplets landing after
        tt = np.arange(int(0.04 * RATE)) / RATE
        f0 = rng.uniform(700, 1300)
        place(out, chirp(tt, f0, f0 * 1.9, 0.04), rng.uniform(0.08, 0.42), rng.uniform(0.08, 0.2))
    return out


def sizzle(rng: random.Random) -> np.ndarray:
    n = int(0.7 * RATE)
    t = np.arange(n) / RATE
    noise = np.array([rng.uniform(-1, 1) for _ in range(n)])
    hiss = highpass(noise, 2500) * np.exp(-t / 0.22) * np.clip(t / 0.01, 0, 1)
    crackle = np.zeros(n)
    for _ in range(60):                                        # pops of bursting bubbles
        i = int(rng.uniform(0, 0.6) * RATE)
        crackle[i] += rng.uniform(-1, 1) * math.exp(-i / RATE / 0.3)
    crackle = highpass(lowpass(crackle, 5000), 800) * 3.0
    tt = np.arange(int(0.18 * RATE)) / RATE
    out = hiss * 0.7 + crackle
    place(out, chirp(tt, 140, 70, 0.18), 0.0, 0.7)             # the thick glorp of going in
    return out


def save(name: str, x: np.ndarray) -> None:
    x = x / max(1e-6, float(np.max(np.abs(x)))) * 0.8
    fade = min(len(x), int(0.01 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    save("splash", splash(random.Random(7)))
    save("sizzle", sizzle(random.Random(11)))
