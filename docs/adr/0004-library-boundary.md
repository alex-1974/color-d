# ADR 0004 — Keep color mathematics independent of consumers

**Status:** Accepted

## Context

The first consumers are imagery processing and an OSM editor theme/style
layer, but their image layout, metadata, semantic roles, and rendering policy
are not general color mathematics.

## Decision

color-d owns typed color values and value-level color mathematics.
imagery-d owns image channel binding, layout, metadata, masks/validity/NoData,
ROI/tiling, and image execution. Theme/style layers own semantic roles and
renderer policy.

## Consequences

color-d remains independently usable and does not depend on imagery-d,
raster-d, GUI frameworks, OSM tags, or rendering APIs. Consumer integration may
refine call shapes before v0.1 but must not silently move these ownership
boundaries.
