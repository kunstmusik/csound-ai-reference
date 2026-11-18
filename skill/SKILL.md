# SKILL: Csound 7 Code Generation

## Trigger
Use this skill whenever generating, editing, or reviewing **Csound** code (`.csd`, `.orc`, `.sco` files).

## Before Writing Any Csound Code

1. Confirm the target version is **Csound 7** unless told otherwise
2. Review the variable rate prefix rules (i/k/a/S/f)
3. Use new-style UDO syntax (`opcode opcode_name(args):returnType` / `endop`)
4. Always include the standard orchestra header (`sr`, `ksmps`, `nchnls`, `0dbfs = 1`)
5. Prefer lowercase names for user-defined opcodes; use `snake_case` when that reads better
6. Prefer CamelCase names for instruments
7. If comments are generated for definitions, use csdoc `/** ... */` docblocks with `@param` and `@return`

## After Writing Code

Run `csound --syntax-check-only file.csd` before rendering: it checks the orchestra and score syntax without rendering and exits 1 if the orchestra does not parse. Exit 0 does not mean the file is fine: score errors, a missing instrument or a missing table can pass and only show up when rendering. To check a render without listening, measure it with `lufs` (see `examples/utility/measure-loudness.csd`).

## Rate Prefix Rules (Non-Negotiable)

Every variable name prefix determines its update rate:
- `i` = init rate (once per note)
- `k` = control rate (every ksmps samples, ~64/sr seconds)
- `a` = audio rate (every sample)
- `S` = string
- `f` = spectral (f-sig)

Opcodes have defined output rates — match the variable prefix to the opcode's output rate.

## UDO Template (Always Use This Form)

```csound
; New-style (Csound 7 — preferred)
opcode udo_name(aSig, kParam):a
  ; processing — args available directly by name
  xout result
endop

; Multiple return values use parenthesized types
opcode stereo_process(aSigL, aSigR, kMix):(a,a)
  ; processing
  xout aOutL, aOutR
endop
```

Type codes for optional args: `:o` (i-rate, default 0), `:O` (k-rate, default 0), `:p`/`:P` (default 1), `:j`/`:J` (default -1).

## csdoc Documentation Format

If you generate comments for UDOs, instruments, or structs, follow **csdoc** format.

Requirements:
- Put a `/** ... */` docblock immediately before the definition
- Use `@param` for UDO parameters and instrument p-fields
- Use `@return` or `@returns` for UDO outputs
- Keep descriptions concrete and concise

Example:

```csound
/**
 * Filtered synth voice.
 *
 * @param aIn Input audio signal
 * @param kCutoff Filter cutoff in Hz
 * @return aOut Filtered audio signal
 */
opcode filtered_voice(aIn, kCutoff):a
  aOut = butlp(aIn, kCutoff)
  xout aOut
endop
```

## Stateful Audio DSP UDO Pattern

For custom filters, BBD lines, delay feedback structures, and other **sample-dependent audio algorithms**, use a manual per-sample loop only when the algorithm truly requires explicit per-sample state updates. If the processing can be expressed correctly with ordinary a-rate signals, prefer that form for performance and clarity.

Default structure:
- `aOut init 0`
- persistent one-sample state in `k` variables with `init`
- coefficient cache in `k` variables
- `kindx = 0`
- `while kindx < ksmps do`
- read `kIn = aIn[kindx]`
- process one sample, update state
- write `aOut[kindx] = kY`

Important:
- In a manual sample loop, `kz1`, `kz2`, and similar names are still correct for one-sample state memory
- Recompute coefficients only when relevant k-rate parameters change
- If a parameter is audio-rate, read it per sample with `aParam[kindx]`
- Do not try to fake recursive DSP with a single a-rate expression
- Do not force a manual sample loop for simple feed-forward or otherwise ordinary a-rate processing
- Use working references such as libsyi's `diode.udo` as the model for structure

## CSD File Template

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

; UDOs go here

instr MySynth
  ; instrument code
endin

</CsInstruments>
<CsScore>
i "MySynth"  0  4
e
</CsScore>
</CsoundSynthesizer>
```

## Key Opcode Signatures to Get Right

| Task | Correct Opcode | Signature |
|------|---------------|----------|
| Sine oscillator | `oscili` | `aSig = oscili(iAmp, kFreq [, iFtable])` |
| Anti-aliased VCO | `vco2` | `aSig = vco2(iAmp, kFreq [, iMode])` |
| ADSR envelope | `transegr` | `kEnv = transegr(0, iAtk, 0, 1, iDec, -4.2, iSus, iRel, -4.2, 0)` |
| Moog filter | `moogladder` | `aOut = moogladder(aSig, kCutoff, kRes)` |
| ZDF filter | `zdf_ladder` | `aOut = zdf_ladder(aSig, kCutoff, kRes)` |
| Schroeder reverb | `reverbsc` | `aL, aR = reverbsc(aInL, aInR, kFb, kCo)` |
| Variable delay | `vdelay` | `aDel = vdelay(aSig, kDelayMs, iMaxMs)` |
| MIDI note→Hz | `cpsmidinn` | `iFreq = cpsmidinn(iMidiNote)` |
| dB→amplitude | `ampdbfs` | `iAmp = ampdbfs(iDb)` |
| Portamento | `port` | `kSmooth = port(kSig, kHalfTime)` |

## Checklist Before Outputting Code

- [ ] All variable names have correct rate prefix
- [ ] UDOs use new-style syntax with named args
- [ ] Orchestra header has `sr`, `ksmps`, `nchnls`, `0dbfs = 1`
- [ ] **All opcodes use functional style** (single: `x = func(...)`, multi-output `a, b = func(...)`)
- [ ] No `cpspch` usage
- [ ] No `cpspch` usage
- [ ] `expseg` values are all > 0
- [ ] `linseg`/`expseg` argument count is odd (value, dur, value, dur, ..., value)
- [ ] UDOs have `xout` for return values
- [ ] `out()` used for stereo output (not deprecated `outs`)
- [ ] Recursive/stateful audio DSP UDOs use an explicit sample loop over `ksmps` only when per-sample state evolution is actually required
- [ ] One-sample filter/delay state is stored in initialized `k` variables and updated inside the loop
- [ ] Coefficients are cached and recomputed only when parameters change

## Consulting the Csound Manual

Csound has 1500+ opcodes. For opcode signatures and detailed behavior, consult the official manual:
- **Manual home**: https://csound.com/manual/
- **Opcode quick reference**: https://csound.com/manual/opcodesQuickRef/
- **Individual opcode pages**: `https://csound.com/manual/opcodes/{opcode_name}/`

## Csound FLOSS Manual

The **Csound FLOSS Manual** (https://flossmanual.csound.com/) is the community textbook recommended for new users. Use it for conceptual explanations, synthesis technique overviews, and practical recipes.

> **Important:** FLOSS Manual examples often use **older-style syntax** — statement-style opcode calls and old-style UDOs with `xin`. Always **modernize to Csound 7 style** when drawing from this resource.

Key chapters:
- Language fundamentals (Ch. 03): https://flossmanual.csound.com/csound-language
- Sound synthesis — additive, subtractive, AM, FM, waveshaping, granular, physical modelling (Ch. 04): https://flossmanual.csound.com/sound-synthesis
- Sound modification — envelopes, filters, delay, reverb, spectral/PVS (Ch. 05): https://flossmanual.csound.com/sound-modification
- MIDI (Ch. 07): https://flossmanual.csound.com/midi
- Opcode guide with 33 essentials, top 100, and extended overview (Ch. 14A): https://flossmanual.csound.com/miscellanea/opcode-guide

## Reference Files (Skill Package)

- `reference/syntax-rules.md` — full rate/type rules
- `reference/opcodes.md` — manual URL directory and common opcode signatures
- `reference/patterns.md` — common synthesis and effects patterns
- `reference/antipatterns.md` — common AI mistakes
- `examples/` — working annotated `.csd` files
