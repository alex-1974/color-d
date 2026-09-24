# R0.8 — Gamut Semantics

Executable research spike for `color-d`.

Research basis:

`docs/research/R0_8_GAMUT_SEMANTICS.md`

The experiment investigates:

- strict sRGB gamut detection;
- epsilon-aware numerical boundary detection;
- encoded/linear-sRGB gamut equivalence;
- non-finite values;
- explicit target-RGB clipping;
- clipping idempotence;
- deltaEOK;
- CSS Local-MINDE gamut mapping;
- CSS Ray Trace gamut mapping;
- constant-lightness / constant-hue chroma reduction;
- mapping identity for already in-gamut colors;
- mapping idempotence;
- float/double;
- CTFE;
- algorithm iteration counts.

EdgeSeeker is intentionally not implemented in this first spike.

This is research code and does not define a stable public API.

`RESULTS.md` is created only after successful observed DMD and LDC runs.

## Reusable research fixture

On 2026-09-24, the previously validated R0.8 mathematical implementation was
mechanically extracted from:

```text
source/app.d
```

into:

```text
fixture/r0_8_gamut_fixture.d
```

The executable `source/app.d` now contains the R0.8 CTFE/invariant probes,
runtime inspection and `main`, and imports the fixture.

The extraction boundary was the existing:

```text
CTFE / invariants
```

section. No gamut mathematics was intentionally changed.

The original validated monolithic source had SHA-256:

```text
3befe5b656ee1e310023e06cd0b71d666ad179e8d98c4892ceb6717a6dca2568
```

Before and after the extraction, the complete executable was run under:

```text
DMD 2.111.0 Debug
DMD 2.111.0 Release
LDC 1.41.0 Debug
LDC 1.41.0 Release
```

All four post-refactor runs exited successfully.

For every compiler/build configuration, the complete 137-line runtime output
was byte-for-byte identical before and after the extraction.

Observed output SHA-256 values were unchanged:

```text
DMD Debug
8dd922bc3e3b2343e81cbfcb70b139e0dd334f5a31975611087a4a55aeac49ce

DMD Release
60a72dca3afa71dc12e2596bfb76f88903e18e45653c4ff974266ab1881ffb11

LDC Debug
9cbdc52985b106e9dcf8e42171884edf5c7829f775d20ffa789ef12c35a61bfe

LDC Release
b2bc6291fc5be2c2fabee89cc811d0d963639fd2932bd07abb6809f86d9040db
```

This fixture exists only to let later research experiments reuse the validated
R0.8 gamut semantics without copying the mapping algorithms.

It is not a stable public `color-d` module or API.
