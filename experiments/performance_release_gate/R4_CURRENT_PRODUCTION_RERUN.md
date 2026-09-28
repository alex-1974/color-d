# R4 current-production performance gate rerun

**Status:** VALIDATED
**Baseline:** `develop` at `ae75e9e2129485239813a21693796a3c342cf978`
**Date:** 2026-09-28
**GitHub:** #46

## Purpose

Re-run the retained release-performance probes against the current integrated
R4 production state after the numerical, API, packaging and test/CI hardening
passes.

This file exists to make the rerun explicit and reviewable. It intentionally
changes no production source and no benchmark implementation.

The retained advisory workflow exercises:

- sRGB encode reciprocal-power production path;
- Ray Trace cube-intersection inline hint;
- Oklab -> OKLCH guarded chroma magnitude;
- XYZ D65 -> linear-sRGB production path;
- Oklab extreme-finite fallback;
- Local MINDE / Ray Trace public production paths.

## Decision rule

The rerun is evidence, not an optimization invitation.

A generated-code/assembly inspection is performed only if the measurements
reveal a concrete unexplained question, such as:

- a material same-process regression against a retained baseline/candidate;
- semantic/hash mismatch;
- exceptional fallback frequency inconsistent with retained evidence;
- loss of the previously justified inline/code-generation effect;
- an unexplained compiler-specific gap in materially comparable work.

Absolute hosted-runner timing drift by itself is not sufficient.

## Result

The retained workflow completed successfully on the current production state.
All validation/hash/reference checks passed.

Observed same-process release evidence:

| Probe | Current observation | Decision |
| --- | --- | --- |
| sRGB encode | LLVM/Phobos median speed ratio about 8.43x (`double`) and 18.67x (`float`); public production/local-Phobos about 8.43x and 18.04x; numerical maxima remain 2 ULP on the public production comparison | retain narrow LDC runtime power path |
| Ray Trace inline | 1,000,000 cases/scalar, 0 exact mismatches; median default/forced ratio about 1.00 for `double` and 1.76 for `float` | retain explicit inline hint because the supported `float` path still has a large stable benefit |
| XYZ -> linear-sRGB | extreme avoidable non-finite cases remain 42 -> 0; ordinary `double` production/reference accuracy remains better and median production/baseline ratio about 0.969; `float` remains bit-identical on 2,000,000 ordinary samples with median ratio about 1.027 | retain scalar-specific production paths |
| Oklab extreme fallback | 1,000,000 ordinary samples/scalar, 0 mismatches; extreme closure PASS; median production/baseline ratio about 1.009 (`double`) and 1.023 (`float`) | accepted correctness guard cost remains small |
| OKLCH chroma | 262,144 ordinary samples/scalar, 0 bit mismatches; representable extreme magnitudes remain repaired; current Intel-hosted ratio about 1.034 (`double`) and 1.029 (`float`) | retain guarded robust path |
| Gamut production | all ordinary/in-gamut/huge-chroma validation failures remain zero and all retained hashes are unchanged; Ray Trace remains much cheaper than Local MINDE on out-of-gamut and especially huge-chroma inputs | no mapper production change |

The OKLCH ratio is the only current measurement near a review-sized ordinary
overhead. The same code/probe previously measured about 1.008 (`double`) and
1.017 (`float`) on an AMD EPYC 7763 runner, while the current run used an
Intel Xeon Platinum 8573C. The guarded path remains bit-identical to the former
ordinary result and fixes real representable overflow/underflow cases.
The variation therefore does not identify an unexplained code-generation
regression.

No current measurement reveals a concrete generated-code question that
justifies an additional assembly/LLVM-IR inspection. Per the audit rule, no
speculative code-generation work is opened merely to search for one.

The final PR head contains documentation/evidence changes only; the retained
performance workflow is re-run once more on that final head before merge.
