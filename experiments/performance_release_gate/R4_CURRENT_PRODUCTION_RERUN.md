# R4 current-production performance gate rerun

**Status:** IN PROGRESS
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

Pending current-production workflow evidence.
