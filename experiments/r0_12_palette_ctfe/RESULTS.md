# R0.12 results — Compile-time palette construction and validation

## R0.12-A — Vertical composition and ownership boundary

**Status:** VALIDATED
**Phase:** R0.12-A
**GitHub:** #8 — R0.12 — Validate compile-time palette construction and validation

R0.12-A tests whether representative multi-family palette construction requires
new mathematical palette semantics or can be expressed as ordinary composition
of already validated color primitives.

It does not test application theme semantics.

No public API is established by this phase.

---

## A.1 Final tested source

The final R0.12-A source had SHA-256:

```text
eec02d05af19ca2bee2ebc8f660a1b0d37b54f0650facc3e21d1ec664b908a93
```

File:

```text
experiments/r0_12_palette_ctfe/source/app.d
```

The hash was recorded before the final compiler matrix and verified unchanged
after all four forced builds.

---

## A.2 Compiler matrix

The final source was force-built and executed under:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release
LDC 1.41.0   Debug
LDC 1.41.0   Release
```

The tested LDC version was:

```text
LDC 1.41.0
based on DMD v2.111.0
LLVM 19.1.7
```

Observed result in every configuration:

```text
18 PASS
0 FAIL
exit 0
```

Matrix:

| Compiler | Build | Result |
|---|---|---:|
| DMD 2.111.0 | Debug | 18/18 PASS |
| DMD 2.111.0 | Release | 18/18 PASS |
| LDC 1.41.0 | Debug | 18/18 PASS |
| LDC 1.41.0 | Release | 18/18 PASS |

Total:

```text
18 checks per configuration
4 configurations

72 PASS
0 FAIL
```

No compiler/build disagreement was observed.

---

## A.3 Tested palette shape

The experiment used:

```text
3 independent families
5 tones per family
float and double
```

The families deliberately had no application semantic names.

They were identified only by position.

This avoids introducing concepts such as:

```text
accent
warning
selected
road.primary
ThemeMode
```

into the mathematical experiment.

---

## A.4 Raw family composition

One raw family is constructed from:

```text
seed OKLCH value
+
explicit lightness schedule
+
explicit chroma schedule
```

The tested operation is mechanically equivalent to repeated scalar component
replacement:

```text
withLightness
withChroma
```

The supplied schedules are authoritative.

The seed contributes its stored hue.

The raw operation does not:

```text
clip
gamut-map
normalize hue
assign application meaning
```

Observed for both scalar types in all four configurations:

```text
PASS  raw L/C schedules and stored hues are exact
```

---

## A.5 Multi-family batch composition

R0.12-A compared:

```text
compose each family independently
```

with:

```text
compose all families through one mechanical palette batch
```

Observed:

```text
PASS  palette batch equals repeated family composition
```

for both:

```text
float
double
```

in every compiler/build configuration.

Therefore the tested multi-family batch adds no observable mathematical
semantics beyond repeated family composition.

At this stage it is only batching/container convenience.

---

## A.6 Explicit out-of-gamut case

The experiment includes the already R0.8-validated high-chroma yellow case:

```text
OKLCH(
    L = 0.96476,
    C = 0.24503,
    H = 110.23 degrees
)
```

Observed:

```text
PASS  known high-chroma yellow remains out of sRGB gamut
```

This confirms that raw palette construction does not silently clip or map the
value.

R0.12-A does not establish this gamut fact independently; it deliberately
reuses the previously validated R0.8 case as an integration fixture.

---

## A.7 Explicit gamut mapping

The experiment applies the R0.8 Ray Trace mapper only after raw palette
construction.

The pipeline therefore remains:

```text
raw OKLCH palette
        ↓
explicit Ray Trace gamut mapping
        ↓
mapped linear-sRGB palette
```

Observed:

```text
PASS  palette mapping batch equals repeated family mapping
PASS  explicit mapping leaves raw palette unchanged
PASS  all explicit Ray Trace mappings report success
PASS  all mapped linear-sRGB tones are in gamut
```

for both scalar types in every final matrix configuration.

Therefore:

```text
raw palette
```

and:

```text
mapped target-gamut result
```

remain separate representations.

The mapper does not rewrite the authoritative raw palette.

---

## A.8 Explicit target-space conversion

Target-space encoding is a separate phase after gamut mapping.

The experiment compares:

```text
encode every mapped family independently
```

with:

```text
encode the mapped palette through one mechanical batch
```

Observed:

```text
PASS  target-space batch equals repeated family conversion
PASS  explicitly encoded sRGB palette is in gamut
```

for both scalar types in every final configuration.

Therefore the tested batch conversion likewise adds no new color semantics.

---

## A.9 Vertical composition

The complete tested path is:

```text
independent OKLCH seeds
        ↓
explicit lightness/chroma schedules
        ↓
raw OKLCH families
        ↓
explicit Ray Trace mapper
        ↓
linear-sRGB mapped families
        ↓
explicit sRGB encoding
        ↓
finite multi-family result
```

This composition worked without introducing:

```text
Palette
PaletteBuilder
Theme
ThemeBuilder
semantic role identifiers
default gamut mapping
implicit clipping
```

as mathematical requirements.

---

## A.10 Batch-helper interpretation

The experiment contains convenience helpers equivalent to:

```text
composeRawPalette
mapPaletteRayTrace
encodeMappedPalette
```

For every tested stage the palette-wide helper produced exactly the same result
as independently applying the corresponding family operation.

Therefore R0.12-A provides no evidence that these batch helpers belong in the
public mathematical API.

They may be ordinary consumer-side loops or convenience operations.

Whether any generalized batch primitive is useful remains separate from whether
it carries color semantics.

---

## A.11 Template-instantiation scaffolding observation

During development, the initial research scaffolding used qualified fixture
template instances directly in function-template signatures.

DMD 2.111.0 did not successfully instantiate those helper calls through the
initial implicit deduction shape.

Local aliases for the extracted R0.8 fixture types removed the qualified-type
lookup problem.

The remaining research helpers involving static-array dimensions were then
called with explicit template parameters:

```text
T
F
N
```

where those parameters were already known by the surrounding experiment.

The final form compiled and executed successfully under both:

```text
DMD 2.111.0
LDC 1.41.0
```

in Debug and Release.

This is an experiment-scaffolding observation.

R0.12-A does not establish:

```text
final public template signatures
final public IFTI ergonomics
a compiler compatibility policy
```

Those questions must not be inferred from this research helper shape.

---

## A.12 Attributes and allocation shape

The low-level composition and batch helpers used in phase A are written as:

```d
@safe
pure
nothrow
@nogc
```

and operate on fixed-size value storage.

The tested phase does not require:

```text
heap allocation
GC allocation
dynamic ownership
a custom palette container
```

This is a property of the tested research shape, not yet a frozen public API
requirement.

---

## A.13 Phase-A conclusions

R0.12-A supports the following conclusions:

1. Multiple independent color families compose through ordinary low-level
   primitives.
2. Explicit lightness and chroma schedules remain authoritative.
3. Stored hue remains explicit raw data.
4. Raw palette construction does not silently gamut-map.
5. A previously validated out-of-gamut tone remains out of gamut in the raw
   palette.
6. Gamut mapping can be applied explicitly after raw construction.
7. Explicit mapping can produce a separate in-gamut result without modifying
   the raw palette.
8. Target-space conversion remains an explicit later stage.
9. Palette-wide batching produced exactly the same tested results as repeated
   family operations.
10. The tested batch helpers therefore add no observed mathematical color
    semantics.
11. Ordinary fixed-size D arrays are sufficient for the tested multi-family
    representation.
12. No application theme semantics are required by the tested pipeline.
13. No custom palette container is justified by phase-A evidence.
14. No policy-heavy palette builder is justified by phase-A evidence.
15. No public API is frozen.

---

## A.14 Not established by R0.12-A

R0.12-A does not yet establish:

- contrast-validation architecture;
- perceptual-distance-validation architecture;
- generic diagnostics/report representation;
- caller acceptance-policy representation;
- runtime/CTFE equivalence of the complete palette pipeline;
- `static immutable` storage conclusions;
- compile-time failure/validation behavior;
- CTFE cost or scaling;
- larger-cardinality behavior;
- edge/property coverage;
- library-wide numerical tolerance policy;
- a public palette type;
- public batch-helper names;
- public template-instantiation ergonomics;
- final production API.

Those questions belong to later R0.12 phases.

---

## A.15 Phase-A status

R0.12-A is complete.

The next phase is:

```text
R0.12-B — Validation composition
```

R0.12 as a whole remains in progress.
