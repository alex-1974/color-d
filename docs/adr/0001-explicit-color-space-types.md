# ADR 0001 — Explicit color-space types and conversions

**Status:** Accepted

## Context

Encoded sRGB, linear-light sRGB, XYZ D65, Oklab, and OKLCH can share similar
physical component layouts while having materially different semantics.

## Decision

Represent materially different color spaces as distinct public types and make
color-space transitions explicit operations. UFCS may provide natural syntax
for the same operation but must not hide policy.

## Alternatives

A generic three-scalar color with runtime tags, implicit constructors, and
cast-style conversions were considered less able to prevent accidental
cross-space use.

## Consequences

The type system catches many semantic mix-ups. Call sites are more explicit,
and consumers must choose conversions deliberately.
