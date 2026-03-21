# Csound 7 — AI Coding Reference

This project uses **Csound 7**. Follow all rules below when generating or editing Csound code.

**Style priority:** Always use modern Csound 7 syntax — functional calling style, new-style UDOs with named arguments, lowercase or `snake_case` names for user-defined opcodes, CamelCase names for instruments, and `out()` for output. Old-style syntax is shown only for reference; never generate it in new code.

---

## Consulting the Csound Manual (IMPORTANT)

Csound has **1500+ opcodes**. This reference covers syntax rules and common patterns, but for **opcode signatures, arguments, and detailed behavior**, always consult the official manual.

- **Manual home**: https://csound.com/manual/
- **Opcode quick reference**: https://csound.com/manual/opcodesQuickRef/
- **Individual opcode pages**: `https://csound.com/manual/opcodes/{opcode_name}/`
  - Example: `vco2` → https://csound.com/manual/opcodes/vco2/
- **GEN routines**: https://csound.com/manual/genIndex/

When unsure about an opcode's arguments or behavior, **look it up** rather than guessing.

## Csound FLOSS Manual

The **Csound FLOSS Manual** (https://flossmanual.csound.com/) is the community textbook and the recommended first stop for new Csound users. It contains interactive examples, conceptual explanations, and practical recipes covering the full language.

> **Important:** FLOSS Manual examples often use **older-style Csound syntax** — statement-style opcode calls and old-style UDOs with `xin`. When drawing on FLOSS Manual content, always **modernize the code** to Csound 7 style (functional calling, new-style UDOs, `out()` for output).

### Key chapters by topic

| Topic | Chapter | URL |
|-------|---------|-----|
| Getting started | 01 | https://flossmanual.csound.com/get-started |
| How-to recipes | 02 | https://flossmanual.csound.com/how-to |
| Language: variables, rates, UDOs, arrays, functional syntax | 03 | https://flossmanual.csound.com/csound-language |
| Additive synthesis | 04A | https://flossmanual.csound.com/sound-synthesis/additive-synthesis |
| Subtractive synthesis | 04B | https://flossmanual.csound.com/sound-synthesis/subtractive-synthesis |
| AM / Ring modulation | 04C | https://flossmanual.csound.com/sound-synthesis/amplitude-and-ring-modulation |
| FM synthesis | 04D | https://flossmanual.csound.com/sound-synthesis/frequency-modulation |
| Waveshaping | 04E | https://flossmanual.csound.com/sound-synthesis/waveshaping |
| Granular synthesis | 04F | https://flossmanual.csound.com/sound-synthesis/granular-synthesis |
| Physical modelling | 04G | https://flossmanual.csound.com/sound-synthesis/physical-modelling |
| Envelopes | 05A | https://flossmanual.csound.com/sound-modification/envelopes |
| Filters | 05C | https://flossmanual.csound.com/sound-modification/filters |
| Delay and feedback | 05D | https://flossmanual.csound.com/sound-modification/delay-and-feedback |
| Reverberation | 05E | https://flossmanual.csound.com/sound-modification/reverberation |
| Spectral processing (PVS) | 05I | https://flossmanual.csound.com/sound-modification/fourier-analysis-spectral-processing |
| MIDI | 07 | https://flossmanual.csound.com/midi |
| Opcode guide (33 essentials → top 100 → full) | 14A | https://flossmanual.csound.com/miscellanea/opcode-guide |

---

## Variable Rate Prefixes (CRITICAL)

Every variable name must be prefixed to indicate its rate:

| Prefix | Rate | Updated |
|--------|------|---------|
| `i` | Init (once per note) | At note start |
| `k` | Control rate | Every k-period (~every 64 samples) |
| `a` | Audio rate | Every sample |
| `S` | String | Init or k-rate |
| `f` | F-sig (spectral) | k-rate |

Global variables add `g` prefix: `gk_tempo`, `gaReverb`, `gi_table`.
Arrays use `[]` suffix: `iArr[]`, `kArr[]`, `aArr[]`.

**Rate promotion rules:**
- **i-rate values can be used freely in k-rate and a-rate expressions.** This is fundamental to Csound — `aSig = vco2(iAmp, iFreq)` is correct and idiomatic.
- **k-rate values auto-promote to a-rate** in a-rate expressions. `aOut = aSig * kAmp` is valid — Csound holds the k-value constant for each k-period block.
- Output rate = highest rate of operands: i < k < a.
- Use `init` to declare and initialize k-rate variables at i-time: `kAmp init 0.5`

---

## UDO Syntax — New Style (Csound 7, PREFERRED)

Use named arguments in the `opcode` declaration. Arguments are available by name — **no `xin` needed**.

```csound
opcode saturate(aSig, kDrive):a
  aOut = tanh(aSig * kDrive) / tanh(kDrive)
  xout aOut
endop
```

**Multiple return types** use parenthesized type list:

```csound
opcode stereo_width(aSig, kWidth):(a,a)
  kDelayMs = kWidth * 12
  aDel = vdelay(aSig, kDelayMs, 20)
  xout aSig, aDel
endop
```

**More examples:**

```csound
; No inputs, one audio output
opcode sine_osc():a
  aOut = oscili(0.5, 440)
  xout aOut
endop

; i-rate and k-rate inputs, audio output
opcode filtered_osc(iFreq, kCutoff):a
  aSig = vco2(0.5, iFreq, 0)
  aOut = moogladder(aSig, kCutoff, 0.5)
  xout aOut
endop

; Array output
opcode make_scale(iSize):k[]
  kOut[] init iSize
  kOut[0] = 261.63
  kOut[1] = 293.66
  xout kOut
endop
```

**Key rules for new-style UDOs:**
- Arguments are named in the declaration — **never add `xin`**
- Prefer lowercase names for user-defined opcodes; `snake_case` is acceptable and generally clearer than CamelCase
- Types are inferred from the variable prefix (`i`, `k`, `a`, `S`, `f`)
- Return type goes after `:` — single type: `:a`, multiple: `:(a,a)`
- `xout` is still required to return values
- Use `:type` suffix for polymorphic opcodes inside UDOs: `linen:a()`, `random:i()`

---

## UDO Syntax — Old Style (Legacy, still supported)

This syntax uses type strings instead of named arguments. **Do not use in new code** — shown only so you can read existing code.

```csound
opcode opcode_name, outputTypeString, inputTypeString
  in1, in2 xin          ; xin IS required in old style
  ; ... body ...
  xout out1
endop
```

Type string characters: `i`=init, `k`=control, `a`=audio, `S`=string, `f`=f-sig, `0`=none, `o`=optional k (default 0), `j`=optional k (default -1), `[]`=array suffix.

---

## Signal-Processing UDOs for Audio (IMPORTANT)

When writing a UDO that performs **stateful audio signal processing** — for example filters, BBDs, waveguides, companders with memory, recursive delays, or any design where the current sample depends on previous samples — first ask whether the algorithm really requires explicit per-sample state updates. If it can be expressed correctly with ordinary a-rate signal processing, prefer that form for clarity and performance. If it cannot, do **not** try to force it into one a-rate formula; write it as an explicit **sample-by-sample loop** inside the UDO.

This is the pattern used by working references such as libsyi's `diode.udo` and should be treated as the default structure for custom DSP UDOs.

### Required structure

1. Declare the output signal and persistent state with `init`
2. Keep per-sample memory/state in **k-rate scalars** such as `kz1`, `kz2`, `kWritePtr`
3. If coefficients depend on k-rate parameters, cache them in k-rate variables and recompute only when the parameter changes
4. Iterate across the current audio block with `kindx = 0` and `while kindx < ksmps do`
5. Read the current input sample with array access: `kIn = aIn[kindx]`
6. For audio-rate modulated parameters, also read them per-sample: `kCutoff = aCutoff[kindx]`
7. Write each output sample explicitly: `aOut[kindx] = kY`
8. Update filter/delay state inside the loop before incrementing `kindx`

### Important rules

- Inside a manual sample loop, it is normal and correct for one-sample memories to use `k` names such as `kz1` and `kz2`
- Use `aOut init 0` before the loop, then fill `aOut[kindx]`
- Separate **coefficient update** logic from **per-sample state update** logic whenever possible
- If k-rate and a-rate parameter versions need materially different handling, prefer separate UDO overloads rather than forcing one ambiguous implementation
- Do not use `reinit` or score-time control flow to emulate per-sample recursion
- Do not invent vectorized formulas for recursive filters unless you know the algorithm is non-recursive

### Skeleton for stateful DSP UDOs

```csound
opcode my_process(aIn, kParam):a
  aOut init 0
  kz1 init 0
  kz2 init 0
  kLastParam init -1
  kb0 init 0
  kb1 init 0
  kb2 init 0
  ka1 init 0
  ka2 init 0

  if kLastParam != kParam then
    ; recompute coefficients here
    kLastParam = kParam
  endif

  kindx = 0
  while kindx < ksmps do
    kIn = aIn[kindx]

    ; direct-form / integrator / delay update here
    kY = (kb0 * kIn) + kz1
    kz1 = (kb1 * kIn) - (ka1 * kY) + kz2
    kz2 = (kb2 * kIn) - (ka2 * kY)

    aOut[kindx] = kY
    kindx += 1
  od

  xout aOut
endop
```

Use this structure only when you need true sample-by-sample state evolution. Otherwise, prefer ordinary a-rate processing.

---

## Instrument Structure

Use **named instruments** (preferred over numbered):

```csound
instr SubSynth
  ; i-rate: compute once at note start
  iFreq = cpsmidinn(p4)             ; MIDI note number to Hz
  iAmp  = (p5 / 127) * ampdbfs(-6)  ; velocity to amplitude

  ; k-rate: evolving over note duration
  kEnv = transegr(0, 0.008, 0, 1, 0.12, -4.2, 0.65, 0.35, -4.2, 0)

  ; a-rate: audio synthesis
  aSig = vco2(iAmp, iFreq, 0)       ; sawtooth oscillator
  aFilt = moogladder(aSig, 2000, 0.3)
  aOut = aFilt * kEnv

  out(aOut, aOut)                    ; stereo output
endin
```

**Key rules:**
- Name instruments with meaningful CamelCase names: `instr SubSynth`, `instr FMBell`
- Use `out(aL, aR)` for stereo output — **`outs` is deprecated** in Csound 7
- Use `cpsmidinn()` for MIDI note to Hz conversion
- Use functional calling style: `aSig = vco2(0.5, 440)` not `aSig vco2 0.5, 440`

---

## Functional Calling Style (PREFERRED)

Csound 7 supports calling opcodes as functions with `=`. Always prefer this style:

```csound
; PREFERRED: Functional style
aSig = vco2(iAmp, iFreq, 0)
aFilt = moogladder(aSig, kCutoff, kRes)
aOut = ntrpol(aDry, aWet, kMix)
iFreq = cpsmidinn(p4)
iAmp = ampdbfs(-12)

; AVOID: Old statement style (still works, but don't generate it)
; aSig  vco2    iAmp, iFreq, 0
; aFilt moogladder aSig, kCutoff, kRes
```

**Type disambiguation** — when an opcode is polymorphic (can output different rates), use `:type` suffix:

```csound
aEnv = linen:a(1, 0.1, p3, 0.1)    ; force a-rate output
iVal = random:i(0, 100)             ; force i-rate output
kEnv = expon:k(1, p3, 0.001)        ; force k-rate output
```

**Note:** Opcodes with **multiple outputs** cannot use `=` style and must use statement style:

```csound
aL, aR reverbsc aDryL, aDryR, kFeedback, kCutoff
aLP zdf_2pole aSig, kCutoff, kRes
```

**This is the ONLY exception.** All single-output opcodes — including envelopes (`linseg`, `linsegr`, `expseg`, `madsr`, `transeg`, `transegr`, etc.) — MUST use functional style. Prefer `transegr` when you want a shaped ADSR-style envelope, typically with linear attack and `-4.2` curved decay/release:

```csound
; CORRECT: functional style for envelopes
kEnv = transegr(0, 0.01, 0, 1, 0.1, -4.2, 0.7, 0.3, -4.2, 0)
kEnv = linsegr(0, 0.01, 1, 0.1, 0.7, 0.2, 0)
kEnv = transegr(0, 0.01, 0, 1, 0.2, -4.2, 0.7, 0.3, -4.2, 0)

; WRONG: old statement style for envelopes — do not generate this
; kEnv  transegr 0, 0.01, 0, 1, 0.1, -4.2, 0.7, 0.3, -4.2, 0
; kEnv  linsegr 0, 0.01, 1, 0.1, 0.7, 0.2, 0
```

---

## Frequency Conversion

```csound
; MIDI note to Hz (preferred)
iFreq = cpsmidinn(p4)

; Semitone offset from a base
iFreq = iBaseFreq * semitone(iSemitones)

; Cents offset (semitone fraction)
iFreq = iBaseFreq * semitone(iCents / 100)

; Direct calculation: 440 * 2^((midi-69)/12)
iFreq = 440 * pow(2, (iMidi - 69) / 12)
```

Avoid `cpspch` (old octave-pitch notation) unless maintaining legacy code.

---

## Amplitude

```csound
; dB full scale to linear (0 dBFS = amplitude 1.0)
iAmp = ampdbfs(-12)

; Velocity scaling (common pattern)
iAmp = (p5 / 127) * ampdbfs(-6)

; Scale by 0dBFS reference
iAmp = 0dbfs * 0.5
```

Always set `0dbfs = 1` in the orchestra header.

---

## Orchestra Header

```csound
<CsoundSynthesizer>
<CsOptions>
-odac -d -m0
</CsOptions>
<CsInstruments>

sr     = 48000
ksmps  = 64
nchnls = 2
0dbfs  = 1

; ... UDOs and instruments ...

</CsInstruments>
<CsScore>
; score events
</CsScore>
</CsoundSynthesizer>
```

**Header variable rules:**
- `sr`: sample rate (44100, 48000, 96000)
- `ksmps`: samples per k-period (32, 64, 128 — lower = more CPU, higher precision for envelopes)
- `nchnls`: output channel count
- `0dbfs = 1` — always set this; without it amplitude scaling is unpredictable

---

## Common Opcodes — Quick Reference

### Oscillators
```csound
aSig = oscili(iAmp, kFreq)              ; sine (default), or with ftable
aSig = oscili(iAmp, kFreq, iFtable)     ; wavetable oscillator
aSig = vco2(iAmp, kFreq)                ; anti-aliased VCO (saw default)
aSig = vco2(iAmp, kFreq, iMode)         ; iMode: 0=saw, 10=square, 12=triangle
aSig = poscil(iAmp, kFreq, iFtable)     ; high-precision oscillator
```

### Envelopes
```csound
kEnv = linseg(ia, idur1, ib, idur2, ic)         ; linear segments (no release)
kEnv = linsegr(ia, idur1, ib, idur2, ic, iRel, id)  ; with release segment
kEnv = expseg(ia, idur1, ib)                    ; exponential (values must be > 0)
kEnv = expsegr(ia, idur1, ib, iRel, ic)         ; exponential with release
kEnv = transegr(0, iAtk, 0, 1, iDec, -4.2, iSus, iRel, -4.2, 0)  ; preferred ADSR-style envelope
kEnv = madsr(iAtk, iDec, iSus, iRel)            ; simple MIDI-style ADSR (acceptable, less explicit)
kEnv = transegr(ia, idur1, itype1, ib, iRelDur, iRelType, ic)  ; general curved segments + release
aEnv = linen:a(iAmp, iRise, iDur, iDec)         ; simple trapezoid (a-rate)
```

### Filters
```csound
aOut = tone(aSig, kCutoff)                     ; 1-pole lowpass
aOut = atone(aSig, kCutoff)                    ; 1-pole highpass
aOut = butlp(aSig, kCutoff)                    ; Butterworth lowpass
aOut = buthp(aSig, kCutoff)                    ; Butterworth highpass
aOut = butbp(aSig, kCutoff, kBw)               ; Butterworth bandpass
aOut = moogladder(aSig, kCutoff, kRes)         ; Moog ladder filter
aOut = zdf_ladder(aSig, kCutoff, kRes)         ; Zero-delay feedback ladder
```

### Reverb / Delay
```csound
; Delay
aDel = vdelay(aSig, kDelayMs, iMaxMs)          ; variable delay

; Delay line (read/write pair)
aDel  delayr  iMaxTime
aTap  deltap3 kDelayTime
      delayw  aSig

; Reverb (multi-output — use statement style)
aL, aR reverbsc aSig, aSig, kFeedback, kCutoff
```

### Distortion / Waveshaping
```csound
aOut = distort1(aSig, kPregain, kPostgain, kShape1, kShape2)  ; 5 required args
aOut = powershape(aSig, kShapeExp)             ; power function waveshaping
aOut = clip(aSig, iMethod, iLimit)             ; hard/soft clipping
aOut = tanh(aSig * kDrive)                     ; simple soft clip
```

### Noise
```csound
aNoise = rand(iAmp)                ; white noise
aNoise = pinkish(iAmp)             ; pink noise
aNoise = gauss(iSigma)             ; gaussian noise
```

### Mixing / Utility
```csound
aOut = aSig1 + aSig2                           ; sum
aOut = ntrpol(aSig1, aSig2, kMix)              ; crossfade (0=sig1, 1=sig2)
kVal = port(kSig, kHalfTime)                   ; portamento / lag filter
iVal = tab_i(iIndex, iFtable)                  ; read ftable at i-time
kVal = tab(kIndex, iFtable)                    ; read ftable at k-rate
```

---

## Score Syntax

```csound
; Named instruments (preferred)
i "SubSynth"  0    2     60  90     ; name, start, dur, p4, p5...
i "FMBell"    2.5  1.5   72  100

; Numbered instruments (still valid)
i 1  0  2

; f statement: f tableNum startTime size genRoutine [args]
f 1  0  4096  10  1           ; sine wave
f 2  0  4096  10  1 0.5 0.3   ; additive: sine + harmonics

; e: end score
e
```

---

## Ftable Generation (GEN routines)

```csound
f 1  0  4096  10  1                ; GEN10: pure sine
f 2  0  4096  10  1 0 0.33 0 0.2   ; GEN10: odd harmonics (square-ish)
f 3  0  4096  7   0 2048 1 2048 0  ; GEN07: triangle (linear segments)
f 4  0  4096  21  1                ; GEN21: Gaussian random
f 5  0  4096  9   1 1 90           ; GEN09: partials with phase
```

---

## Arrays (Csound 7)

```csound
; Declare
iArr[] init 8          ; i-rate array, 8 elements
kArr[] init 16         ; k-rate array

; Set/get
iArr[0] = 1.0
kVal = kArr[2]

; Array-returning UDO (new style)
opcode make_scale(iSize):k[]
  kOut[] init iSize
  kOut[0] = 261.63
  kOut[1] = 293.66
  xout kOut
endop
```

---

## MIDI Handling

```csound
instr MIDISynth
  ; These opcodes only work inside MIDI-triggered instruments
  iMidi  notnum                     ; MIDI note number (0-127)
  iFreq  = cpsmidinn(iMidi)
  iVel   veloc 0, 127               ; velocity (scaled to range)
  iAmp   = (iVel / 127) * ampdbfs(-6)

  kBend  pchbend 0, 2               ; pitch bend in semitones (+/- 2)
  kMod   midictrl 1                 ; CC1 = mod wheel

  aSig = oscili(iAmp, iFreq * semitone(kBend))

  out(aSig, aSig)
endin
```

For MIDI, add `-M0 -Q0` or equivalent to CsOptions, and use `massign` to route channels.

---

## Channels & Software Bus

```csound
; Write to named channel
chnset kValue, "myChannel"
chnset aSignal, "audioOut"

; Read from named channel
kValue chnget "myChannel"
aSig   chnget "audioOut"

; Useful for inter-instrument communication and OSC/host automation
```

---

## Common Mistakes to Avoid

1. **Wrong rate prefix** — `kSig = vco2(0.5, 440)` is wrong; `vco2` outputs audio (`a`).
2. **Missing `0dbfs = 1`** — amplitude will be off by a factor of 32768.
3. **Using `xin` in new-style UDOs** — new-style `opcode opcode_name(args):type` names args in the declaration; adding `xin` is redundant and wrong.
4. **Using `cpspch`** — use `cpsmidinn()` or direct Hz arithmetic instead.
5. **Zero values in `expseg`** — all values must be strictly positive (> 0). Use 0.0001 instead of 0.
6. **`linseg` duration mismatch** — arguments alternate `value, duration, value, duration, ..., value` — final value has no duration.
7. **Missing `xout` in UDOs** — `xout` is always required to return values (both old and new style).
8. **Using `outs`** — deprecated in Csound 7. Use `out(aL, aR)` instead.
9. **Old calling style in new code** — prefer `aSig = vco2(0.5, 440)` over `aSig vco2 0.5, 440`. This applies to **all** single-output opcodes including envelopes: prefer `kEnv = transegr(...)`, with `kEnv = linsegr(...)` or `kEnv = madsr(...)` only when that simpler shape is specifically intended. Statement style is only for multi-output opcodes.
10. **Wrong `distort1` args** — needs 5: `distort1(aSig, kPregain, kPostgain, kShape1, kShape2)`.