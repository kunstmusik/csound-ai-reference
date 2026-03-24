# Csound 7 — Common Patterns

## Synthesis Patterns

### Subtractive Synthesis

```csound
opcode sub_synth_voice(kFreq, kCutoff, kRes):a
  ; Oscillator with slight detuning for richness
  aSaw1 = vco2(0.4, kFreq)
  aSaw2 = vco2(0.4, kFreq * 1.005)   ; +0.5 cents detune
  aSaw3 = vco2(0.4, kFreq * 0.995)   ; -0.5 cents detune
  aMix  = aSaw1 + aSaw2 + aSaw3

  ; Filter with envelope
  aOut = moogladder(aMix, kCutoff, kRes)
  xout aOut
endop

instr SubSynth
  iFreq  = cpsmidinn(p4)
  iAmp   = ampdbfs(-12)

  kAmpEnv  = transegr(0, 0.01, 0, 1, 0.1, -4.2, 0.7, 0.3, -4.2, 0)
  kFiltEnv = transegr(0, 0.005, 0, 1, 0.2, -4.2, 0.4, 0.4, -4.2, 0)

  kCutoff = 200 + kFiltEnv * 3000   ; envelope opens filter

  aSig = sub_synth_voice(iFreq, kCutoff, 0.3)
  aOut = aSig * kAmpEnv * iAmp

  out(aOut, aOut)
endin
```

### FM Synthesis (2-Operator)

```csound
opcode fm2op(kCarrFreq, kModRatio, kModIndex, kAmp):a
  kModFreq = kCarrFreq * kModRatio
  kModAmp  = kModFreq * kModIndex    ; FM index scales with mod frequency

  aMod = oscili(kModAmp, kModFreq)
  aOut = oscili(kAmp, kCarrFreq + aMod)
  xout aOut
endop

instr FMSynth
  iFreq = cpsmidinn(p4)
  iAmp  = ampdbfs(-10)

  kEnv  = linsegr(0, 0.01, 1, p3-0.05, 0.8, 0.05, 0)
  ; Modulation index sweeps for brighter attack
  kIdx  = linsegr(5, 0.1, 1.5, p3-0.1, 1.5, 0.1, 0)

  aSig = fm2op(iFreq, 2, kIdx, iAmp)
  aOut = aSig * kEnv

  out(aOut, aOut)
endin
```

### Additive Synthesis (Partial Stack)

```csound
opcode additive_synth(kFreq, iAmps[], kDetunes[]):a
  iNumPartials = lenarray:i(iAmps)
  aMix = 0
  iPartial = 0

  while iPartial < iNumPartials do
    aPartial = oscili(iAmps[iPartial], kFreq * (iPartial + 1) + kDetunes[iPartial])
    aMix += aPartial
    iPartial += 1
  od

  xout aMix
endop
```

### Wavetable Synthesis

```csound
instr WaveTable
  iTable = p4      ; ftable number passed as parameter
  iFreq  = cpsmidinn(p5)
  iAmp   = ampdbfs(-6)

  kEnv  = linsegr(0, 0.005, 1, p3-0.1, 0.9, 0.1, 0)
  aSig = poscil(iAmp, iFreq, iTable)    ; poscil = high-accuracy oscillator

  out(aSig * kEnv, aSig * kEnv)
endin
```

### Granular Synthesis (Basic)

```csound
instr GranularSynth
  iSoundFile = p4   ; sample table
  iAmp       = ampdbfs(-6)

  kGrainRate  = 25                ; grains per second
  kGrainDur   = 0.08              ; grain duration in seconds
  kPitch      = 1.0               ; pitch ratio
  kPosition   = 0.5              ; position in source (0-1)

  aSig  granule iAmp, kGrainRate, kGrainDur, kPitch, iSoundFile, \
                kPosition, 0.05, 0, 0, 0

  out(aSig, aSig)
endin
```

---

## Effects Patterns

### Stereo Reverb with Wet/Dry Mix

```csound
opcode stereo_reverb(aDryL, aDryR, kRoomSize, kWetMix):(a,a)
  ; Clamp room size to valid range
  kRoom = (kRoomSize > 0.98) ? 0.98 : kRoomSize

  aWetL, aWetR = reverbsc(aDryL, aDryR, kRoom, 8000)

  aOutL = ntrpol(aDryL, aWetL, kWetMix)
  aOutR = ntrpol(aDryR, aWetR, kWetMix)
  xout aOutL, aOutR
endop
```

### Tempo-Synced Delay

```csound
opcode sync_delay(aSig, kBPM, kFeedback, iSubdivision):a
  ; iSubdivision: 1=quarter, 2=eighth, 4=sixteenth
  kDelayTime = (60 / kBPM) / iSubdivision
  kDelayMs   = kDelayTime * 1000
  iMaxMs     = 2000

  aDel  = vdelay(aSig, kDelayMs, iMaxMs)
  aOut  = aSig + aDel
  xout  aOut
endop
```

### Ping-Pong Delay

```csound
opcode ping_pong_delay(aSig, kBPM, kFeedback, iSubdivision):(a,a)
  kDelayMs = (60000 / kBPM) / iSubdivision
  iMaxMs   = 4000

  ; Left tap feeds right, right tap feeds left
  aDelL = vdelay(aSig + aDelR * kFeedback, kDelayMs, iMaxMs)
  aDelR = vdelay(aSig + aDelL * kFeedback, kDelayMs * 0.5, iMaxMs)

  aOutL = aSig + aDelL
  aOutR = aSig + aDelR
  xout aOutL, aOutR
endop
```

### Chorus / Ensemble

```csound
opcode chorus(aSig, kDepth, kRate):(a,a)
  ; Multiple modulated delay taps
  kMod1 = oscili(kDepth, kRate)
  kMod2 = oscili(kDepth, kRate * 1.1, 0, 0.25)    ; phase offset
  kMod3 = oscili(kDepth, kRate * 0.9, 0, 0.5)

  iBase = 20   ; base delay in ms
  iMax  = 50

  aCh1 = vdelay(aSig, iBase + kMod1 * 10, iMax)
  aCh2 = vdelay(aSig, iBase + kMod2 * 10, iMax)
  aCh3 = vdelay(aSig, iBase + kMod3 * 10, iMax)

  ; Spread to stereo
  aOutL = (aSig + aCh1) * 0.5
  aOutR = (aSig + aCh2 + aCh3) * 0.5
  xout aOutL, aOutR
endop
```

### Soft Saturation

```csound
opcode saturate(aSig, kDrive, kMix):a
  aDriven = aSig * kDrive
  aSat    = distort1(aDriven, 1, 0.5, 0, 0)  ; soft clip (pregain, postgain, shape1, shape2)
  ; Compensate for gain increase
  aComp = aSat / kDrive
  aOut  = ntrpol(aSig, aComp, kMix)
  xout  aOut
endop
```

### Parametric EQ Band

```csound
opcode para_eq(aSig, kFreq, kGainDB, kQ):a
  ; Convert dB to linear for gain
  kGain = pow(10, kGainDB / 20)

  ; Peak/notch filter via peaking EQ formula
  aOut = pareq(aSig, kFreq, kGain, kQ, 1)   ; mode 1 = peaking
  xout aOut
endop
```

### Stateful DSP UDO Skeleton

```csound
opcode stateful_process(aIn, kParam):a
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
    ; coefficient update goes here
    kLastParam = kParam
  endif

  kindx = 0
  while kindx < ksmps do
    kIn = aIn[kindx]
    kY = (kb0 * kIn) + kz1
    kz1 = (kb1 * kIn) - (ka1 * kY) + kz2
    kz2 = (kb2 * kIn) - (ka2 * kY)
    aOut[kindx] = kY
    kindx += 1
  od

  xout aOut
endop
```

Use this only when the current sample depends on previous samples and ordinary a-rate processing cannot express the algorithm correctly. This is the correct shape for custom IIR filters and related DSP, and matches the working style of references such as libsyi's `diode.udo`. If a normal a-rate opcode graph is sufficient, prefer that for performance and clarity.

### Butterworth Lowpass from Scratch

```csound
opcode butterlp2(aIn, kCutoff):a
  aOut init 0
  kz1 init 0
  kz2 init 0
  kLastCutoff init -1
  kb0 init 0
  kb1 init 0
  kb2 init 0
  ka1 init 0
  ka2 init 0
  kQ = 0.7071067811865475

  if kLastCutoff != kCutoff then
    kSafeCutoff = kCutoff
    if kSafeCutoff < 20 then
      kSafeCutoff = 20
    elseif kSafeCutoff > (sr * 0.45) then
      kSafeCutoff = sr * 0.45
    endif

    kOmega = (2 * $M_PI * kSafeCutoff) / sr
    kSin = sin(kOmega)
    kCos = cos(kOmega)
    kAlpha = kSin / (2 * kQ)
    kA0 = 1 + kAlpha

    kb0 = ((1 - kCos) * 0.5) / kA0
    kb1 = (1 - kCos) / kA0
    kb2 = ((1 - kCos) * 0.5) / kA0
    ka1 = (-2 * kCos) / kA0
    ka2 = (1 - kAlpha) / kA0
    kLastCutoff = kCutoff
  endif

  kindx = 0
  while kindx < ksmps do
    kIn = aIn[kindx]
    kY = (kb0 * kIn) + kz1
    kz1 = (kb1 * kIn) - (ka1 * kY) + kz2
    kz2 = (kb2 * kIn) - (ka2 * kY)
    aOut[kindx] = kY
    kindx += 1
  od

  xout aOut
endop
```

---

## Envelope Patterns

### Preferred ADSR (Named Parameters)

```csound
opcode adsr(kAtk, kDec, kSus, kRel):k
  kEnv = transegr(0, kAtk, 0, 1, kDec, -4.2, kSus, kRel, -4.2, 0)
  xout kEnv
endop
```

### Looping LFO

```csound
opcode lfo_shape(kFreq, kDepth, iShape, kPhase:O):k
  ; iShape: 0=sine, 1=triangle, 2=square, 3=sawtooth
  kLFO = oscili(kDepth, kFreq, iShape + 1)   ; ftable 1=sine, 2=tri etc.
  xout kLFO
endop
```

### Triggered Envelope

```csound
; Envelope that re-triggers on k-rate gate signal
opcode trig_env(kGate, kAtk, kDec, kRel):k
  kTrig  trigger kGate, 0.5, 0    ; detect rising edge
  kEnv   = linsegr(0, 0.001, 1, kAtk, 1, kDec, 0)
         reinit  ; restart on trigger
  xout   kEnv
endop
```

---

## MIDI and Real-Time Patterns

### Basic MIDI Instrument

```csound
instr MIDISynth
  ; MIDI opcodes auto-fill from MIDI event
  iMidi  notnum
  iFreq  = cpsmidinn(iMidi)
  iVel   veloc   0, 127
  iAmp   = (iVel / 127) * 0dbfs * 0.5

  kEnv   = transegr(0, 0.01, 0, 1, 0.1, -4.2, 0.8, 0.3, -4.2, 0)
  kBend  pchbend 0, 2                  ; pitch bend ±2 semitones
  kMod   midictrl 1, 0, 1              ; CC1 mod wheel, range 0-1

  ; Mod wheel controls vibrato
  kVib = oscili(kMod * 0.5, 5)         ; vibrato depth * rate
  aSig = vco2(iAmp, iFreq * semitone(kBend + kVib))

  kFiltCut = 500 + kMod * 3000
  aOut = moogladder(aSig, kFiltCut, 0.3)
  aOut *= kEnv

  out(aOut, aOut)
endin
```

### Channel Routing / Mixdown

```csound
; Instruments write to global buses; mixer instrument reads and outputs
instr SynthVoice
  ; ... synthesis ...
  chnmix aOut, "synthBus"
endin

instr DrumVoice
  ; ... drum synthesis ...
  chnmix aKick, "drumBus"
endin

instr Master  ; always-on mixer
  aSynth chnget "synthBus"
  aDrum  chnget "drumBus"

  ; Apply reverb to synth
  aRevL, aRevR = reverbsc(aSynth, aSynth, 0.8, 8000)
  aMixL = aSynth * 0.6 + aRevL * 0.4 + aDrum * 0.9
  aMixR = aSynth * 0.6 + aRevR * 0.4 + aDrum * 0.9

  out(aMixL, aMixR)

  ; Clear buses
  chnclear "synthBus"
  chnclear "drumBus"
endin
```

---

## Audio File Playback

```csound
instr PlayFile
  SFile  = p4             ; file path from score string
  iAmp   = ampdbfs(-6)
  iSpeed = 1.0            ; playback speed (1 = normal)

  aSigL, aSigR = diskin2(SFile, iSpeed, 0, 1)  ; loop=1

  out(aSigL * iAmp, aSigR * iAmp)
endin
```

```csound
; Score string parameter
i "PlayFile"  0  4  "mysound.wav"
```
