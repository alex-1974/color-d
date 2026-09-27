# ADR 0002 — Preserve extended values and natural floating `.init`

**Status:** Accepted

## Context

Intermediate color mathematics can legitimately produce components outside
nominal display intervals. Redefining floating value-type defaults as black
would also turn uninitialized state into a plausible color.

## Decision

Computational colors preserve extended values unless a specifically named
operation defines clipping or mapping. Promoted floating-point value types keep
their natural NaN-based `.init` state as detectably invalid/uninitialized
semantic state.

`HuePath` is intentionally different: its `.init` is the valid
`shorter` policy.

## Consequences

Callers cannot assume construction implies target-gamut validity. Accidental
default use remains visible, while explicit gamut and validation operations
retain clear responsibility.
