; ============================================================
; butterworth-lowpass-udo.csd
; Demonstrates: writing a stateful audio DSP UDO from scratch
; using a manual sample loop over ksmps.
; ============================================================

<CsoundSynthesizer>
<CsOptions>
-odac -d -m0
</CsOptions>
<CsInstruments>

sr     = 48000
ksmps  = 64
nchnls = 2
0dbfs  = 1

; ============================================================
; UDO: butterlp2
; 2-pole Butterworth lowpass implemented as a biquad.
; This is written from scratch rather than calling butlp.
; ============================================================
opcode butterlp2(aIn, kCutoff):a
  aOut init 0

  ; Direct Form II Transposed state.
  kz1 init 0
  kz2 init 0

  ; Cached normalized coefficients.
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

    ; RBJ cookbook lowpass coefficients with Butterworth Q.
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

; ============================================================
; SweepDemo: bright source passed through the custom filter.
; ============================================================
instr SweepDemo
  iFreq = cpsmidinn(p4)
  iAmp = ampdbfs(-16)

  kAmpEnv = transegr(0, 0.01, 0, 1, 0.12, -4.2, 0.8, 0.25, -4.2, 0)
  kCutoff = expon:k(300, p3, 6500)

  aSaw = vco2(iAmp * 0.85, iFreq)
  aNoise = pinkish(iAmp * 0.08)
  aIn = (aSaw + aNoise) * kAmpEnv

  aOut = butterlp2(aIn, kCutoff)
  out(aOut, aOut)
endin

</CsInstruments>
<CsScore>
i "SweepDemo" 0 3.0 48
i "SweepDemo" 3.5 3.0 55
i "SweepDemo" 7.0 3.5 60
e
</CsScore>
</CsoundSynthesizer>