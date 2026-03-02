<CsoundSynthesizer>
<CsOptions>
-odac -d -m0
</CsOptions>
<CsInstruments>

sr     = 48000
ksmps  = 32
nchnls = 2
0dbfs  = 1

; ─── Global Tables ────────────────────────────────────────────────────────────
giSine ftgen 1, 0, 4096, 10, 1           ; pure sine wave
giCos  ftgen 2, 0, 4096, 9,  1, 1, 90   ; cosine (GEN09: freq=1, amp=1, phase=90°)

; ─── Global Reverb Accumulators ───────────────────────────────────────────────
gaRevL init 0
gaRevR init 0

; ─────────────────────────────────────────────────────────────────────────────
; UDO: PMPair
;
; A two-operator Phase Modulation cell, implemented via the FM-equivalent of PM.
;
; DX-style PM:
;   output(t) = sin( 2π·fc·t  +  β · sin(2π·fm·t) )
;
; Instantaneous frequency:
;   fc  +  β·fm · cos(2π·fm·t)
;
; This is identical to FM with a COSINE modulator of peak amplitude β·fm.
; Using a cosine table (giCos) for the modulator therefore gives exact PM behaviour.
;
; Arguments
;   iCarFreq  — carrier frequency in Hz
;   iModRatio — modulator : carrier frequency ratio
;   kModIdx   — PM index β (radians; 0 = pure sine carrier)
;
; Returns: a-rate output, normalised −1 … +1
; ─────────────────────────────────────────────────────────────────────────────
opcode PMPair(iCarFreq, iModRatio, kModIdx):a
  iModFreq = iCarFreq * iModRatio
  ; Cosine modulator: amplitude = β · fm  (FM-equivalent of PM index β)
  aMod     = oscili(kModIdx * iModFreq, iModFreq, giCos)
  ; Carrier frequency-modulated by aMod → produces DX-style phase modulation
  aOut     = oscili(1.0, iCarFreq + aMod)
  xout aOut
endop

; ─────────────────────────────────────────────────────────────────────────────
; Instrument: Reverb
;
; Always-on stereo plate reverb fed from the global accumulator buses.
; Schedule once with a duration long enough to cover the entire performance.
; ─────────────────────────────────────────────────────────────────────────────
instr Reverb
  aRevL, aRevR reverbsc gaRevL, gaRevR, 0.82, 8000
  out(aRevL * 0.25, aRevR * 0.25)
  clear gaRevL, gaRevR
endin

; ─────────────────────────────────────────────────────────────────────────────
; Instrument: ElPiano
;
; 4-Operator Phase Modulation Electric Piano
;
; Algorithm (two parallel carrier-modulator stacks, as in DX11 Algorithm 5):
;
;   Op2  (ratio 14 : 1)  ──▶  Op1  (ratio 1 : 1)  ──┐
;                                                      ├──▶ MIX ──▶ OUT
;   Op4  (ratio  1 : 1)  ──▶  Op3  (ratio 1 : 1)  ──┘
;
; Pair 1 — Attack / Clang layer
;   Op2's ratio-14 modulator creates inharmonic upper partials (the classic
;   "tine" clang).  The PM index decays rapidly so these partials vanish within
;   ~60–80 ms, leaving only the fundamental.
;
; Pair 2 — Body / Sustain layer
;   Both operators at ratio 1 produce a harmonically rich FM spectrum that
;   slowly evolves toward a clean sine as the index fades over the note's life.
;
; Velocity sensitivity: scales the initial PM index on both pairs, giving
;   lighter touches a softer, more sine-like onset (like a real Rhodes).
;
; Stereo tremolo at ~5 Hz with a 90° L/R phase offset to recreate the
;   auto-pan sweep heard through a classic tremolo amplifier.
;
; p4 = MIDI note number (0–127)
; p5 = velocity         (0–127)
; ─────────────────────────────────────────────────────────────────────────────
instr ElPiano
  iFreq    = cpsmidinn(p4)
  iVelNorm = p5 / 127.0
  iAmp     = iVelNorm * ampdbfs(-6)

  ; Velocity controls initial brightness: softer = fewer harmonics (like a real tine)
  iBright  = 0.35 + iVelNorm * 0.65          ; range 0.35 … 1.0

  ; ── Amplitude Envelope ──────────────────────────────────────────────────────
  ; Near-instantaneous attack (4 ms), long exponential decay, short release.
  ; Electric piano tines have no real sustain — it's all decay.
  kAmpEnv  = expsegr(0.001, 0.004, 1.0, p3 + 0.01, 0.003, 0.5, 0.0001)

  ; ── Pair 1: Attack / Clang (Op2 ratio=14 → Op1 ratio=1) ────────────────────
  ; PM index β₁: high at attack → drops fast → clang disappears in ~60–80 ms
  kIdx1    = linseg(3.2 * iBright, 0.06, 0.4 * iBright, 1.5, 0.0)
  aCar1    = PMPair(iFreq, 14.0, kIdx1)

  ; ── Pair 2: Body / Sustain (Op4 ratio=1 → Op3 ratio=1) ─────────────────────
  ; PM index β₂: moderate at attack, decays slowly toward zero to give
  ; harmonic richness that mellows over the note's lifetime.
  kIdx2    = linsegr(1.8 * iBright, p3 * 0.7, 0.3 * iBright, p3 * 0.3, 0.0, 0.5, 0.0)
  aCar2    = PMPair(iFreq, 1.0, kIdx2)

  ; ── Mix ─────────────────────────────────────────────────────────────────────
  ; Both pairs contribute equally; clang pair handles attack, body pair sustains.
  aMix     = aCar1 * 0.50 + aCar2 * 0.50

  ; ── Stereo Tremolo ──────────────────────────────────────────────────────────
  ; Two LFO instances 90° apart (0.25 × full cycle) — gives the characteristic
  ; "wobble" of a Rhodes through a tremolo amp, widened into stereo.
  iTremRate  = 5.0                              ; ~5 Hz (typical for Rhodes-style tremolo)
  iTremDepth = 0.10                             ; ±10% amplitude modulation
  aTremL     = oscili(iTremDepth, iTremRate, giSine, 0.00)
  aTremR     = oscili(iTremDepth, iTremRate, giSine, 0.25)   ; 90° = 0.25 in table units

  ; ── Final Output ────────────────────────────────────────────────────────────
  aDryL      = aMix * iAmp * kAmpEnv * (1.0 - iTremDepth + aTremL)
  aDryR      = aMix * iAmp * kAmpEnv * (1.0 - iTremDepth + aTremR)

  ; Feed a small amount to the global reverb bus (direct + early sound first)
  gaRevL    += aDryL * 0.18
  gaRevR    += aDryR * 0.18

  out(aDryL, aDryR)
endin

</CsInstruments>
<CsScore>

; Always-on reverb — duration covers entire score + tail
i "Reverb"  0  35

; ─── Demo: ii–V–I–IV progression in C major ──────────────────────────────────
; Each chord voiced as a close-position seventh, arpeggiated upward.
;
;  i "ElPiano"  start  dur  note  vel

; Dm7  (ii)
i "ElPiano"   0.0   5.0   62   80   ; D4
i "ElPiano"   0.1   5.0   65   74   ; F4
i "ElPiano"   0.2   5.0   69   70   ; A4
i "ElPiano"   0.3   5.0   72   76   ; C5

; G7   (V)
i "ElPiano"   5.5   5.0   67   84   ; G4
i "ElPiano"   5.6   5.0   71   78   ; B4
i "ElPiano"   5.7   5.0   74   74   ; D5
i "ElPiano"   5.8   5.0   77   80   ; F5

; Cmaj7  (I)
i "ElPiano"  11.0   5.0   60   88   ; C4
i "ElPiano"  11.1   5.0   64   82   ; E4
i "ElPiano"  11.2   5.0   67   78   ; G4
i "ElPiano"  11.3   5.0   71   84   ; B4

; Fmaj7  (IV)
i "ElPiano"  16.5   5.0   65   82   ; F4
i "ElPiano"  16.6   5.0   69   76   ; A4
i "ElPiano"  16.7   5.0   72   72   ; C5
i "ElPiano"  16.8   5.0   76   78   ; E5

e
</CsScore>
</CsoundSynthesizer>
