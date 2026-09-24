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

R0.12-B follows below.

R0.12 as a whole remains in progress.

---

# R0.12-B — Validation composition

**Status:** VALIDATED
**Phase:** R0.12-B

R0.12-B tests whether palette validation is better represented as composition
of mathematical measurements plus caller-owned acceptance policy, rather than
as one opaque universal palette validator.

No public API is established by this phase.

---

## B.1 Final tested source

The final R0.12-B source had SHA-256:

```text
db5d087073c8b71df0bbb8b08811bf68c0e6ccc4ae9cf352350dfa454069b66f
```

File:

```text
experiments/r0_12_palette_ctfe/source/app.d
```

The hash was recorded before the final compiler matrix and verified unchanged
after all four forced builds.

---

## B.2 Compiler matrix

The final source was force-built and executed under:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release
LDC 1.41.0   Debug
LDC 1.41.0   Release
```

Observed in every configuration:

```text
R0.12-A: 18 PASS, 0 FAIL
R0.12-B: 28 PASS, 0 FAIL
exit 0
```

R0.12-B matrix:

| Compiler | Build | B result |
|---|---|---:|
| DMD 2.111.0 | Debug | 28/28 PASS |
| DMD 2.111.0 | Release | 28/28 PASS |
| LDC 1.41.0 | Debug | 28/28 PASS |
| LDC 1.41.0 | Release | 28/28 PASS |

Therefore:

```text
28 B checks per configuration
4 configurations

112 R0.12-B PASS
0 R0.12-B FAIL
```

Accumulated through R0.12-B:

```text
R0.12-A   72 PASS
R0.12-B  112 PASS

total    184 PASS
           0 FAIL
```

No compiler/build disagreement was observed.

---

## B.3 Validation architecture under test

The experiment distinguishes three separate concepts:

```text
measurement
    ↓
caller-selected comparison pair
    ↓
caller-selected acceptance policy
```

Examples:

```text
WCAG-2 contrast measurement
deltaEOK measurement
raw lightness ordering
```

are distinct from decisions such as:

```text
contrast >= requested minimum
deltaEOK >= requested minimum
family must be nondecreasing
```

The latter are caller policy.

---

## B.4 Caller-selected comparison pairs

The experiment uses positional palette references only.

Conceptually:

```text
ToneRef(family, tone)
TonePair(first, second)
```

No application semantics are attached to those positions.

The experiment does not introduce role names such as:

```text
text
background
accent
selected
warning
```

Pair selection therefore remains explicit caller data.

---

## B.5 WCAG-2 measurement composition

R0.12-B reuses the R0.9 measurement semantics for encoded sRGB values in the
valid finite `[0,1]` WCAG domain.

Observed for all final configurations:

```text
PASS  all encoded palette colors satisfy WCAG sRGB domain
PASS  caller-selected same-tone contrast is exactly 1
PASS  caller-selected endpoint contrast is greater than 1
```

For the selected achromatic endpoint pair, the printed measurement was:

```text
endpoint contrast = 15.2745
```

for both tested scalar types in all four final configurations.

The exact printed value is an observed research result, not a library-wide
reference constant.

---

## B.6 Caller-owned contrast thresholds

The same measured endpoint contrast was evaluated against two caller-supplied
thresholds.

Observed:

```text
PASS  minimum contrast 4.5 accepts the selected endpoints
PASS  minimum contrast 18 rejects the selected endpoints
```

The measurement operation itself contains neither threshold.

Therefore:

```text
contrast measurement
```

and:

```text
required contrast
```

remain separate concerns.

R0.12-B does not establish either `4.5` or `18` as a color-d default.

They are deliberate research policy examples.

---

## B.7 deltaEOK measurement composition

R0.12-B reuses the R0.10 same-space Oklab Euclidean-distance semantics.

Observed:

```text
PASS  caller-selected same-tone deltaEOK is exactly 0
PASS  caller-selected endpoint deltaEOK is greater than 0
```

For the selected achromatic endpoint pair, the printed measurement was:

```text
endpoint deltaEOK = 0.8
```

for both scalar types in all final configurations.

Again, this value belongs to the tested palette fixture and pair.

It is not a universal perceptual threshold.

---

## B.8 Caller-owned deltaEOK thresholds

The same measured distance was evaluated against two caller-selected
thresholds.

Observed:

```text
PASS  minimum deltaEOK 0.5 accepts the selected endpoints
PASS  minimum deltaEOK 0.9 rejects the selected endpoints
```

Therefore the experiment cleanly separates:

```text
distance measurement
```

from:

```text
minimum acceptable distance
```

R0.12-B provides no evidence for embedding one universal perceptual-separation
threshold in color-d.

---

## B.9 Structural lightness policy

The experiment also tests raw lightness ordering independently of contrast and
distance measurement.

Observed:

```text
PASS  caller-selected family is nondecreasing in raw lightness
PASS  the same ascending family does not satisfy descending policy
```

No epsilon is required for this tested structural property because the raw
explicit schedule itself is authoritative.

The required direction remains caller policy.

---

## B.10 Aggregate bool candidate

For comparison, R0.12-B includes a research-local aggregate validator
conceptually equivalent to:

```text
validatePaletteAggregate(
    palette,
    caller policy
) -> bool
```

The policy still supplies:

```text
comparison pairs
contrast threshold
deltaEOK threshold
lightness-order requirement
```

so the aggregate candidate does not introduce universal thresholds.

Observed:

```text
PASS  aggregate bool accepts a passing caller policy
PASS  aggregate bool rejects a caller contrast failure
PASS  aggregate bool rejects a caller distance failure
```

However, both failing cases are represented externally only as:

```text
false
```

The bool alone does not preserve whether the failed condition was:

```text
contrast
```

or:

```text
deltaEOK
```

The individual measurements retain that information.

---

## B.11 Diagnostics implication

The experiment therefore exposes a distinction between:

```text
accept/reject
```

and:

```text
why the palette was accepted or rejected
```

A bare aggregate bool can be useful as a final caller-side gate, but it is not
sufficient as the sole representation of validation evidence when diagnostics
matter.

R0.12-B does not yet design a generic diagnostic/report type.

It establishes only that reducing independent measurements directly to one bool
loses information.

---

## B.12 Measurement versus policy conclusion

The validated composition model is:

```text
explicit measurement
        ↓
caller observes value
        ↓
caller applies explicit threshold / structural rule
        ↓
caller decides acceptance
```

This model allows the same mathematical measurement to participate in multiple
different policies without changing the measurement primitive.

The phase therefore provides no evidence for a universal policy-bearing:

```text
validatePalette(...)
```

primitive in the mathematical core.

---

## B.13 Numerical-policy boundary

R0.12-B deliberately does not introduce a universal epsilon.

The tested exact structural cases include:

```text
same-tone contrast == 1
same-tone deltaEOK == 0
raw lightness ordering
```

The acceptance thresholds are caller policy, not approximation tolerances.

Library-wide tolerance and reference policy remains the responsibility of
R0.13 / GitHub #9.

---

## B.14 Phase-B conclusions

R0.12-B supports the following conclusions:

1. Palette validation can be composed from independent mathematical
   measurements and structural predicates.
2. Comparison-pair selection remains explicit caller data.
3. WCAG-2 contrast measurement does not require a built-in palette threshold.
4. `deltaEOK` measurement does not require a built-in palette threshold.
5. Different caller thresholds can accept or reject the same measured value.
6. Raw lightness-order requirements remain explicit caller policy.
7. A final bool gate can be composed from those policies.
8. A bare aggregate bool loses the identity of the failed condition.
9. The underlying measurements retain diagnostically useful information.
10. No universal palette validator is justified by phase-B evidence.
11. No universal contrast threshold is justified.
12. No universal perceptual-distance threshold is justified.
13. No universal numerical epsilon is introduced.
14. No application semantic roles are required.
15. No public API is frozen.

---

## B.15 Not established by R0.12-B

R0.12-B does not yet establish:

- a public validation-report type;
- a public diagnostics API;
- a generic error-bitset representation;
- compile-time validation failure presentation;
- runtime/CTFE equivalence of the complete palette pipeline;
- `static immutable` palette storage;
- CTFE cost/scaling;
- larger palette cardinalities;
- final edge/property coverage;
- library-wide tolerance policy;
- final production API names.

Those remain later R0.12 or R0.13 concerns.

---

## B.16 Phase-B status

R0.12-B is complete.

The next phase is:

```text
R0.12-C — Representation and CTFE
```

R0.12 as a whole remains in progress.
