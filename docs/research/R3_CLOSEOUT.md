# R3 — Perceptual Utilities Production API Closeout

Date: 2026-09-27

Status: **PASS / COMPLETE**

Tracked by GitHub issue #12.

## Scope completed

R3 promoted the accepted R0.8–R0.11 perceptual, measurement, gamut and
tone-generation semantics into production:

- Oklab `deltaEOK`;
- WCAG-2 relative luminance and contrast measurement;
- explicit Local MINDE perceptual sRGB gamut mapping;
- explicit Ray Trace perceptual sRGB gamut mapping;
- raw OKLCH `withLightness`, `withChroma`, and `withHue`;
- inclusive finite scalar `linearSchedule!N(start, end)`;
- compile-time-sized raw tone-family output;
- runtime-sized caller-owned tone-family output.

The production work was merged through R3.1–R3.6.

## Measurement boundary

`deltaEOK` remains direct Euclidean distance in Oklab.

It does not imply:

- a generic `deltaE` family;
- JND classification;
- hidden conversion;
- clipping;
- gamut mapping.

WCAG-2 measurements remain standards-specific to encoded or linear sRGB and
require the strict finite `[0,1]` measurement domain.

They do not silently:

- clip;
- gamut-map;
- resolve alpha;
- infer a background;
- attach AA/AAA application policy.

## Gamut-mapping boundary

Local MINDE and Ray Trace are both explicit public operations.

There is no default gamut mapper and no generic public method selector.

Clipping and perceptual gamut mapping remain separate operations.

Finite extreme raw hue/chroma handling was hardened during production promotion
without turning NaN or infinity into valid colors.

## Raw OKLCH operations

The scalar OKLCH component operations are deliberately raw:

- `withLightness` changes only lightness;
- `withChroma` changes only chroma;
- `withHue` changes only stored raw hue.

They do not clamp, canonicalize, normalize, clip, gamut-map, or attach theme
policy.

Powerless hue remains stored at zero chroma and can become meaningful again if
chroma is restored.

## Finite scalar schedules

`linearSchedule!N(start, end)` provides the accepted generated finite schedule
primitive:

- `N >= 2`;
- `float` / `double`;
- finite endpoints;
- inclusive exact endpoints;
- ascending, descending, and constant schedules through one API;
- finite extended values are not restricted to `[0,1]`;
- no non-finite generated-schedule contract;
- no aesthetic curve policy.

Interior arithmetic uses the validated R0.11 hybrid rule:

- strictly opposite-sign endpoints use weighted-endpoint arithmetic;
- other finite endpoints use direct-difference arithmetic;
- endpoints are assigned explicitly.

## Tone-family batch representation

The accepted low-level raw tone-family semantics are:

`tonesAtLightnessAndChromaInto`
: compile-time-known cardinality with statically equal lightness, chroma, and
  output arrays.

`tryTonesAtLightnessAndChromaInto`
: runtime-known cardinality with caller-owned slices and an explicit boolean
  success boundary.

For the runtime-sized form:

- success requires
  `lightnesses.length == chromas.length == output.length`;
- mismatch is all-or-nothing;
- mismatch performs zero output writes;
- valid empty input/output returns `true`.

No custom tone-family container, lazy range, allocating convenience layer,
anchor repair, gamut policy, or Palette/Theme abstraction is introduced.

## TC-0001 transport specialization

R0.11 research treated by-value `Oklch!T[N]` return as the natural
compile-time-known representation.

The later workspace toolchain audit recorded TC-0001: DMD 2.111.0–2.113.0 can
silently return wrong values for small static arrays of three-float structs.
`Oklchf` is in that risk class.

R3.6 therefore deliberately does **not** promote the by-value transport form.

The production static-array boundary uses:

- `ref const` lightness/chroma static-array inputs;
- caller-owned `ref Oklch!T[N]` output.

This preserves the accepted static representation and scalar semantics while
following the validated workspace workaround.

The workaround should be reconsidered only when the declared minimum DMD is
known not to contain TC-0001.

## Attributes and allocation model

The promoted low-level R3 core retains, where applicable:

`@safe pure nothrow @nogc`

and ordinary CTFE capability.

Tone schedules and tone-family generation do not require hidden heap or GC
allocation.

No CTFE-specific duplicate API family is introduced.

## Integrated compiler verification

Reference compilers:

```text
DMD 2.113.0
LDC 1.43.0 / frontend 2.113.0
```

R3 slice promotion was verified repeatedly through the repository Fast CI:

- DMD debug unittests;
- DMD release unittests;
- LDC debug unittests;
- LDC release unittests;
- external curated-root compile smoke;
- external supported direct-module compile smoke.

R3.6 additionally verifies:

- static cardinalities including 0, 1, 5, and 32;
- static/runtime representation equivalence;
- repeated scalar-composition equivalence;
- CTFE under float and double;
- mismatch/no-write behavior;
- valid empty runtime output;
- raw extended and non-finite component preservation;
- external compile-negative static-length mismatch;
- the TC-0001-safe static transport form under DMD 2.113.0 and LDC 1.43.0.

The Release Gate remains part of later promotion/release qualification and is
not substituted by this R3 closeout.

## Exit result

The complete accepted R1–R3 production feature scope for v0.1 is now present.

R3 is complete.

This closes the planned pre-consumer feature-promotion phase. New v0.1 feature
scope should now require explicit evidence rather than being added opportunistically.

The public API is **not frozen**. R4 real-consumer validation remains mandatory,
and pre-1.0 API corrections remain allowed where imagery-d or the OSM
theme/style consumer exposes friction.

Release stabilization follows successful R4 consumer validation.
