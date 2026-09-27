# ADR 0003 — Keep gamut detection, clipping, and mapping explicit

**Status:** Accepted

## Context

Conversion, strict target-gamut membership, hard clipping, and perceptual gamut
mapping answer different questions. A single hidden/default policy would make
consumer intent difficult to review.

## Decision

Expose strict sRGB gamut diagnostics and hard clipping separately. Expose Local
MINDE and Ray Trace as explicitly named perceptual mapping algorithms. Do not
freeze a default gamut mapper.

## Alternatives

Implicit clipping during conversion and a generic default mapper were rejected.
EdgeSeeker remains outside the current v0.1 scope.

## Consequences

Consumers must select display policy explicitly. Out-of-gamut intermediate
values remain available for mathematically correct pipelines.
