; ============================================================
; measure-loudness.csd
; Demonstrates: loudness metering with lufs (ITU-R BS.1770)
; Plays a 1 kHz sine at -20 dBFS for 4 seconds, then at -40 dBFS for
; 4 seconds, and prints the three loudness values once a second. Use the
; same pattern on a master bus to check a render without listening to it.
; Run: csound measure-loudness.csd
; Check syntax only: csound --syntax-check-only measure-loudness.csd
; ============================================================

<CsoundSynthesizer>
<CsOptions>
-n
</CsOptions>
<CsInstruments>

sr     = 48000
ksmps  = 32
nchnls = 2
0dbfs  = 1

/**
 * Stereo test tone that measures its own loudness.
 * Prints momentary, short-term and integrated loudness in LUFS.
 */
instr Tone
  kAmp = (timeinsts() < 4) ? ampdbfs(-20) : ampdbfs(-40)
  aSig = oscili(kAmp, 1000)
  out(aSig, aSig)

  ; reset the meter on the first k-cycle only
  kReset = (timeinstk() == 1) ? 1 : 0

  ; outputs, in this order: momentary (400 ms window), integrated (gated, whole
  ; run since the reset), short-term (3 s window)
  kMomentary, kIntegrated, kShortTerm = lufs(kReset, aSig, aSig)

  printks("t=%.0fs  momentary %.1f  short-term %.1f  integrated %.1f LUFS\n", 1, timeinsts(), kMomentary, kShortTerm, kIntegrated)
endin

</CsInstruments>
<CsScore>
i "Tone" 0 8
e
</CsScore>
</CsoundSynthesizer>
