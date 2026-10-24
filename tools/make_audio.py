"""Müzik ve ses efektleri (saf Python sentezi, ek kütüphane gerekmez).

Çalıştırma (proje klasöründen):  python tools/make_audio.py
Çıktı: assets/audio/*.wav (22050 Hz, mono, 16 bit)

  music_chill.wav  sakin lo-fi (82 bpm, Fmaj7-Em7-Dm7-Cmaj7, elektrik piyano, yumuşak davul, plak cızırtısı)
  music_fight.wav  gergin dövüş müziği (150 bpm, La minör, bozuk bas, arpej, sert davul)
  sfx_*.wav        yumruk, tekme, blok, ıska, nakavt, para, tık, kapı, metrobüs zili, korna, bildirim, tepsi
Müzikler döngüye uygun üretilir: sona taşan nota kuyrukları başa sarılır.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = random.Random(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


class Track:
    def __init__(self, seconds, loop=True):
        self.n = int(seconds * SR)
        self.buf = [0.0] * self.n
        self.loop = loop

    def add(self, start, samples):
        i0 = int(start * SR)
        for k, v in enumerate(samples):
            i = i0 + k
            if i >= self.n:
                if not self.loop:
                    break
                i %= self.n
            self.buf[i] += v

    def lowpass(self, alpha):
        y = 0.0
        for _ in range(2):   # döngünün başı da yumuşasın diye iki tur
            for i in range(self.n):
                y += alpha * (self.buf[i] - y)
                self.buf[i] = y

    def save(self, name, gain=0.9):
        peak = max(1e-6, max(abs(v) for v in self.buf))
        data = bytearray()
        for v in self.buf:
            x = math.tanh(v / peak * 1.15) * gain
            data += struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32000))
        with wave.open(os.path.join(OUT, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(bytes(data))


# ---------------------------------------------------------------- Sesler (örnek dizileri döndürür)

def env(t, attack, decay):
    return (t / attack if t < attack else 1.0) * math.exp(-max(0.0, t - attack) * decay)


def epiano(f, dur, amp):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        e = env(t, 0.006, 2.2)
        v = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(4 * math.pi * f * t) * math.exp(-t * 6) \
            + 0.12 * math.sin(6 * math.pi * f * t) * math.exp(-t * 9)
        out.append(v * e * amp * (1.0 + 0.04 * math.sin(2 * math.pi * 4.5 * t)))
    return out


def pad(f, dur, amp):
    out = []
    n = int(dur * SR)
    for i in range(n):
        t = i / SR
        a = min(1.0, t / 0.5) * min(1.0, (n - i) / (0.6 * SR))
        v = 0.0
        for det in (-0.004, 0.0, 0.005):
            ph = (f * (1 + det) * t) % 1.0
            v += 4 * abs(ph - 0.5) - 1.0   # üçgen
        out.append(v / 3 * a * amp)
    return out


def bass(f, dur, amp, grit=0.0):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        e = env(t, 0.004, 3.0 if grit == 0 else 1.5) * min(1.0, (dur - t) / 0.02)
        v = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t)
        if grit:
            ph = (f * t) % 1.0
            v = 0.6 * v + grit * (2 * ph - 1)
            v = math.tanh(v * 2.2)
        out.append(v * e * amp)
    return out


def lead(f, dur, amp):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        e = env(t, 0.003, 9.0)
        ph = (f * t) % 1.0
        v = (1.0 if ph < 0.35 else -1.0) * 0.6 + math.sin(2 * math.pi * f * t) * 0.4
        out.append(v * e * amp)
    return out


def kick(amp, deep=False):
    out = []
    phase = 0.0
    dur = 0.32 if deep else 0.26
    for i in range(int(dur * SR)):
        t = i / SR
        f = (45 if deep else 50) + (110 if deep else 90) * math.exp(-t * 30)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-t * (9 if deep else 12)) * amp)
    return out


def snare(amp, bright=0.5):
    out = []
    lp = 0.0
    for i in range(int(0.22 * SR)):
        t = i / SR
        nz = rng.uniform(-1, 1)
        lp += 0.35 * (nz - lp)
        v = (lp * (1 - bright) + nz * bright) * math.exp(-t * 22) + 0.5 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 30)
        out.append(v * amp)
    return out


def hat(amp, open_=False):
    out = []
    prev = 0.0
    for i in range(int((0.12 if open_ else 0.04) * SR)):
        t = i / SR
        nz = rng.uniform(-1, 1)
        v = nz - prev
        prev = nz
        out.append(v * math.exp(-t * (30 if open_ else 90)) * amp)
    return out


def crackle(track, density, amp):
    for _ in range(int(track.n * density)):
        i = rng.randrange(track.n)
        track.buf[i] += rng.uniform(-1, 1) * amp
    lp = 0.0
    for i in range(track.n):   # plak hışırtısı
        lp += 0.05 * (rng.uniform(-1, 1) - lp)
        track.buf[i] += lp * amp * 0.25


# ---------------------------------------------------------------- Müzikler

def music_chill():
    bpm = 82
    beat = 60.0 / bpm
    bars = 8
    tr = Track(bars * 4 * beat)
    chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]   # Fmaj7 Em7 Dm7 Cmaj7
    roots = [41, 40, 38, 36]
    melody = [[72, None, 69, 67, None, 64, 67, None], [71, None, 67, None, 64, 62, None, 64],
              [69, None, 65, 64, None, 62, 60, None], [64, None, 67, 71, None, 72, None, None]]
    swing = beat * 0.16
    for bar in range(bars):
        c = bar % 4
        t0 = bar * 4 * beat
        tr.add(t0, pad(midi(chords[c][0] + 12), 4 * beat, 0.05))
        for k, n in enumerate(chords[c]):   # piyano akoru: 1. vuruş ve 2'nin arkası (hafif dağıtılmış)
            tr.add(t0 + k * 0.012, epiano(midi(n), 2.4, 0.11))
            tr.add(t0 + 1.5 * beat + swing + k * 0.01, epiano(midi(n + (12 if k == 3 else 0)), 1.6, 0.06))
        tr.add(t0, bass(midi(roots[c]), beat * 1.6, 0.32))
        tr.add(t0 + 2.5 * beat + swing, bass(midi(roots[c] + 7), beat * 0.9, 0.22))
        tr.add(t0 + 3 * beat, bass(midi(roots[c]), beat * 0.8, 0.24))
        if bar >= 4:   # ikinci yarıda melodi
            for k, n in enumerate(melody[c]):
                if n is not None:
                    tr.add(t0 + k * beat / 2 + (swing if k % 2 else 0), epiano(midi(n), 0.9, 0.07))
        for b in range(4):
            bt = t0 + b * beat
            if b in (0, 2):
                tr.add(bt, kick(0.5))
            if b == 2 and bar % 2:
                tr.add(bt + beat / 2 + swing, kick(0.32))
            if b in (1, 3):
                tr.add(bt, snare(0.16, 0.2))
            tr.add(bt, hat(0.06))
            tr.add(bt + beat / 2 + swing, hat(0.04))
    crackle(tr, 0.0004, 0.12)
    tr.lowpass(0.45)
    tr.save("music_chill.wav", 0.8)


def music_fight():
    bpm = 150
    beat = 60.0 / bpm
    bars = 8
    tr = Track(bars * 4 * beat)
    prog = [(45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62]), (40, [56, 59, 64])]   # Am F G E
    for bar in range(bars):
        root, chord = prog[bar % 4]
        t0 = bar * 4 * beat
        for k in range(8):   # sekizlik bozuk bas
            tr.add(t0 + k * beat / 2, bass(midi(root + (12 if k in (3, 7) else 0)), beat / 2 * 0.9, 0.3, grit=0.6))
        arp = chord + [chord[1] + 12]
        for k in range(16):  # onaltılık arpej (ikinci yarıda bir oktav yukarı)
            n = arp[k % 4] + (12 if bar >= 4 else 0)
            tr.add(t0 + k * beat / 4, lead(midi(n), beat / 4 * 0.95, 0.07))
        tr.add(t0, pad(midi(chord[0]), 4 * beat, 0.06))
        for b in range(4):
            bt = t0 + b * beat
            tr.add(bt, kick(0.7, deep=True))
            if b in (1, 3):
                tr.add(bt, snare(0.42, 0.6))
            for h in range(2):
                tr.add(bt + h * beat / 2, hat(0.08, open_=(h == 1 and b == 3)))
        if bar % 4 == 3:   # geçiş: trampet dolgusu
            for k in range(4):
                tr.add(t0 + 3 * beat + k * beat / 4, snare(0.25 + 0.05 * k, 0.6))
    tr.lowpass(0.7)
    tr.save("music_fight.wav", 0.85)


# ---------------------------------------------------------------- Efektler

def sfx(name, seconds, fn, gain=0.9):
    tr = Track(seconds, loop=False)
    fn(tr)
    tr.save(name, gain)


def s_punch(tr):
    tr.add(0, kick(0.9))
    tr.add(0, snare(0.5, 0.2))


def s_kick(tr):
    tr.add(0, kick(1.0, deep=True))
    tr.add(0.01, snare(0.6, 0.15))


def s_block(tr):
    out = []
    for i in range(int(0.08 * SR)):
        t = i / SR
        out.append((math.sin(2 * math.pi * 520 * t) * 0.6 + rng.uniform(-1, 1) * 0.4) * math.exp(-t * 60))
    tr.add(0, out)


def s_whoosh(tr):
    out = []
    lp = 0.0
    n = int(0.28 * SR)
    for i in range(n):
        t = i / n
        lp += (0.05 + 0.4 * math.sin(math.pi * t)) * (rng.uniform(-1, 1) - lp)
        out.append(lp * math.sin(math.pi * t) ** 2)
    tr.add(0, out)


def s_ko(tr):
    tr.add(0, kick(1.0, deep=True))
    tr.add(0.0, bass(55, 0.9, 0.8))
    out = []
    for i in range(int(1.0 * SR)):
        t = i / SR
        out.append(math.sin(2 * math.pi * 880 * t) * math.exp(-t * 3) * 0.2 + math.sin(2 * math.pi * 1320 * t) * math.exp(-t * 4) * 0.1)
    tr.add(0.05, out)


def tone(f, dur, amp, decay=8.0, square=False):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        ph = (f * t) % 1.0
        v = (1.0 if ph < 0.5 else -1.0) * 0.5 if square else math.sin(2 * math.pi * f * t)
        out.append(v * amp * env(t, 0.004, decay))
    return out


def s_coin(tr):
    tr.add(0, tone(988, 0.08, 0.5, 20, True))
    tr.add(0.07, tone(1319, 0.35, 0.5, 8, True))


def s_click(tr):
    tr.add(0, tone(1400, 0.04, 0.5, 80))


def s_door(tr):
    out = []
    lp = 0.0
    n = int(0.6 * SR)
    for i in range(n):
        t = i / SR
        lp += 0.25 * (rng.uniform(-1, 1) - lp)
        out.append(lp * env(t, 0.03, 4.0))
    tr.add(0, out)
    tr.add(0.45, kick(0.5))


def s_ding(tr):
    tr.add(0, tone(1046, 0.8, 0.45, 3))
    tr.add(0.35, tone(784, 1.0, 0.45, 3))


def s_horn(tr):
    out = []
    for i in range(int(0.4 * SR)):
        t = i / SR
        v = 0.0
        for f in (370, 466):
            v += 1.0 if (f * t) % 1.0 < 0.5 else -1.0
        out.append(v * 0.3 * min(1.0, t / 0.01) * min(1.0, (0.4 - t) / 0.03))
    tr.add(0, out)


def s_notify(tr):
    for k, f in enumerate((880, 1175, 1568)):
        tr.add(k * 0.08, tone(f, 0.18, 0.4, 14))


def s_tray(tr):
    out = []
    for i in range(int(0.3 * SR)):
        t = i / SR
        v = sum(math.sin(2 * math.pi * f * t) * a for f, a in ((2100, 0.5), (3350, 0.3), (5230, 0.2)))
        out.append(v * math.exp(-t * 18))
    tr.add(0, out)
    tr.add(0.06, [x * 0.6 for x in out])


def s_buy(tr):
    tr.add(0, snare(0.3, 0.8))
    tr.add(0.05, tone(1568, 0.5, 0.45, 6))
    tr.add(0.05, tone(2093, 0.5, 0.25, 6))


def main():
    os.makedirs(OUT, exist_ok=True)
    music_chill()
    music_fight()
    for name, sec, fn in (("sfx_punch.wav", 0.3, s_punch), ("sfx_kick.wav", 0.4, s_kick), ("sfx_block.wav", 0.12, s_block),
                          ("sfx_whoosh.wav", 0.3, s_whoosh), ("sfx_ko.wav", 1.1, s_ko), ("sfx_coin.wav", 0.45, s_coin),
                          ("sfx_click.wav", 0.06, s_click), ("sfx_door.wav", 0.8, s_door), ("sfx_ding.wav", 1.4, s_ding),
                          ("sfx_horn.wav", 0.42, s_horn), ("sfx_notify.wav", 0.45, s_notify), ("sfx_tray.wav", 0.4, s_tray),
                          ("sfx_buy.wav", 0.6, s_buy)):
        sfx(name, sec, fn)
    print("Sesler üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
