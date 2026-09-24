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

R0.12-C follows below.

R0.12 as a whole remains in progress.

---

# R0.12-C — Representation and CTFE

**Status:** VALIDATED
**Phase:** R0.12-C

R0.12-C tests whether the already composed palette pipeline can use ordinary D
value representations at compile time and runtime without a dedicated CTFE API
or a color-d-owned palette container.

It also tests what form of runtime/CTFE agreement is actually supported by the
observed floating-point behavior.

No public API is established by this phase.

---

## C.1 Final tested source

The final R0.12-C source had SHA-256:

```text
d98344ab479f22a8a2abbeb8f69801ea70a7aaa748a847c51efc3a0e05fcec52
```

File:

```text
experiments/r0_12_palette_ctfe/source/app.d
```

The hash was recorded before the final compiler matrix and verified unchanged
after all four forced builds.

---

## C.2 Compiler matrix

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
R0.12-C: 22 PASS, 0 FAIL
exit 0
```

R0.12-C matrix:

| Compiler | Build | C result |
|---|---|---:|
| DMD 2.111.0 | Debug | 22/22 PASS |
| DMD 2.111.0 | Release | 22/22 PASS |
| LDC 1.41.0 | Debug | 22/22 PASS |
| LDC 1.41.0 | Release | 22/22 PASS |

Therefore:

```text
22 C checks per configuration
4 configurations

88 R0.12-C PASS
0 R0.12-C FAIL
```

Accumulated through R0.12-C:

```text
R0.12-A   72 PASS
R0.12-B  112 PASS
R0.12-C   88 PASS

total    272 PASS
           0 FAIL
```

The compile-time `static assert` checks are additional compile-success evidence
and are not counted in the runtime PASS totals.

---

## C.3 Representation under test

The experiment continues to use ordinary fixed-size D arrays:

```text
Oklch[N][F]
MapResult[N][F]
SRgb[N][F]
```

A consumer-local research struct groups those three representations:

```text
PaletteBundle
    raw
    mapped
    encoded
```

The struct adds no palette policy or color semantics.

It is only an ordinary value aggregate used to test whether a dedicated
color-d palette container is necessary.

---

## C.4 Same ordinary build function

The complete tested construction path is represented by one ordinary function:

```text
buildPaletteBundle(...)
```

Conceptually:

```text
seeds + schedules
        ↓
raw OKLCH palette
        ↓
explicit Ray Trace mapping
        ↓
mapped linear sRGB
        ↓
explicit sRGB encoding
```

The same function is used for:

```text
runtime construction
enum CTFE construction
static immutable initialization
```

No separate compile-time builder or CTFE-specific API is required by the tested
shape.

---

## C.5 Compile-time construction

Both scalar types successfully construct the complete bundle as manifest
compile-time values:

```text
enum phaseCBundleF
enum phaseCBundleD
```

Those values include:

```text
raw palette
mapped palette
encoded palette
```

Therefore the full tested construction pipeline executes under CTFE.

---

## C.6 Compile-time validation

Compile-time `static assert` checks successfully validate properties including:

```text
Ray Trace mapping success
mapped linear-sRGB gamut
encoded sRGB gamut
WCAG sRGB domain
raw lightness ordering
caller-selected contrast policy
caller-selected deltaEOK policy
```

The experiment therefore requires no separate runtime-only validation path for
these tested operations.

A successful compiler matrix is the evidence for these assertions; they do not
produce runtime PASS lines.

---

## C.7 static immutable storage

The same ordinary build function also initializes module-scope:

```text
static immutable PaletteBundle!(...)
```

for both:

```text
float
double
```

The initialization compiled successfully in every final matrix configuration.

Therefore a compile-time-built palette result can be stored directly as an
ordinary statically initialized immutable value in the tested representation.

---

## C.8 enum CTFE versus static immutable

The experiment compares the manifest compile-time result with the
`static immutable` result.

For both scalar types the diagnostic result was:

```text
raw      0 mismatching tones
mapped   0 mismatching tones
encoded  0 mismatching tones
metadata 0 mismatches
```

Maximum component difference:

```text
raw      0
mapped   0
encoded  0
```

The corresponding exact-equality checks all pass.

Therefore, in this experiment:

```text
enum CTFE result == static immutable result
```

exactly for the complete stored bundle.

---

## C.9 Runtime versus CTFE raw representation

Runtime construction and CTFE construction produce exactly equal raw OKLCH
palette values.

Observed for both scalar types and all four configurations:

```text
PASS  runtime raw palette equals CTFE raw palette exactly
```

The diagnostic maximum raw difference is:

```text
0
```

Therefore the explicit input/schedule composition itself is bit-for-bit stable
between runtime and CTFE in the tested shape.

---

## C.10 Runtime versus CTFE mapped values

Exact equality does not hold after the floating-point conversion and Ray Trace
mapping pipeline.

All 15 tested tones show at least one mapped component difference between
runtime and CTFE.

Observed maximum absolute component differences were:

| Scalar | mapped maximum |
|---|---:|
| float | 2.92062759399414062e-06 |
| double | 1.33226762955018785e-15 |

These maxima were the same in all four tested compiler/build configurations.

The experiment deliberately does not introduce a tolerance to turn these
numeric differences into approximate equality.

Tolerance policy belongs to R0.13.

---

## C.11 Runtime versus CTFE encoded values

The later sRGB encoding likewise is not bit-for-bit identical between runtime
and CTFE.

All 15 tested tones show at least one encoded component difference.

Observed maximum absolute component differences were:

| Scalar | encoded maximum |
|---|---:|
| float | 1.54972076416015625e-06 |
| double | 8.88178419700125232e-16 |

Again, no R0.12 tolerance is inferred from these measurements.

The values are observations of this experiment, not proposed library-wide
epsilon constants.

---

## C.12 Algorithmic-path agreement

Despite the numeric component drift, the Ray Trace metadata agrees exactly
between runtime and CTFE.

For both scalar types:

```text
metadata mismatches = 0
```

The exact metadata check covers:

```text
iterations
success
```

Observed:

```text
PASS  runtime and CTFE Ray Trace metadata agree exactly
```

Therefore the tested runtime/CTFE differences do not indicate a different
Ray Trace success state or iteration path.

---

## C.13 Validation-outcome agreement

Runtime and CTFE also agree on all tested semantic classifications and caller
policy outcomes:

```text
mapping-success classification
mapped-gamut classification
encoded-gamut classification
WCAG-domain classification
contrast-policy outcomes
deltaEOK-policy outcomes
```

All corresponding checks pass for both scalar types in every final matrix
configuration.

Therefore the observed floating-point drift does not change any tested
validation decision.

---

## C.14 Build-mode observation

Individual low-order runtime/CTFE component differences are not necessarily
identical across build modes.

In particular, DMD Release showed a different first observed `double`
component-difference pattern than DMD Debug.

However:

```text
raw exactness remained unchanged
Ray Trace metadata remained exact
all tested classifications remained unchanged
all caller policy outcomes remained unchanged
maximum observed mapped drift remained unchanged
maximum observed encoded drift remained unchanged
```

This reinforces that bit-for-bit equality of post-conversion floating-point
values is not an appropriate general runtime/CTFE contract for the tested
pipeline.

R0.12-C does not attempt to explain or standardize compiler floating-point
implementation details.

---

## C.15 Meaning of runtime/CTFE agreement

The evidence supports a more precise definition of agreement for this pipeline.

The tested invariant set is:

```text
raw values:
    exact runtime/CTFE equality

algorithmic metadata:
    exact runtime/CTFE equality

validation classifications:
    same outcomes

caller acceptance policies:
    same outcomes

enum CTFE vs static immutable:
    exact equality
```

For post-conversion numeric values:

```text
bit-for-bit runtime/CTFE equality is not observed
```

R0.12-C therefore does not establish exact numeric equality as a required
contract for such floating-point transformations.

---

## C.16 CTFE API implication

The same ordinary functions successfully serve runtime and compile-time use.

The experiment provides no evidence that color-d needs separate APIs such as:

```text
buildPaletteCTFE
validatePaletteCTFE
CtfePalette
CompileTimePalette
```

CTFE is a property of the ordinary operations rather than a separate palette
abstraction in the tested design.

---

## C.17 Container implication

The tested pipeline works with:

```text
ordinary static arrays
+
a consumer-local ordinary aggregate
```

No experiment result requires a dedicated public:

```text
Palette
PaletteBuilder
PaletteStorage
PaletteView
```

type.

This does not prove that no convenience abstraction could ever be useful.

It means R0.12-C provides no mathematical or CTFE requirement for one.

---

## C.18 Tolerance boundary

The observed runtime/CTFE floating-point drift is intentionally not converted
into a new epsilon policy.

R0.12-C establishes the existence and measured magnitude of the drift for this
fixture.

It does not establish:

```text
absolute tolerance
relative tolerance
ULP tolerance
scalar-specific tolerance
compiler-specific tolerance
```

Those questions belong to R0.13 / GitHub #9.

---

## C.19 Phase-C conclusions

R0.12-C supports the following conclusions:

1. The complete tested palette pipeline executes under CTFE.
2. Compile-time palette validation works with ordinary predicates and
   measurements.
3. The same ordinary build function serves runtime and CTFE use.
4. The complete result can initialize `static immutable` storage.
5. `enum` CTFE and `static immutable` results are exactly equal in the tested
   representation.
6. Raw runtime and CTFE palette values are exactly equal.
7. Runtime and CTFE Ray Trace `iterations` and `success` agree exactly.
8. Runtime and CTFE agree on all tested gamut/domain classifications.
9. Runtime and CTFE agree on the tested contrast-policy decisions.
10. Runtime and CTFE agree on the tested deltaEOK-policy decisions.
11. Post-conversion mapped values are not bit-for-bit runtime/CTFE identical.
12. Post-conversion encoded values are not bit-for-bit runtime/CTFE identical.
13. The observed numeric drift is scalar-dependent and can show low-order
    build-mode variation.
14. No tolerance is invented in R0.12 to hide that observation.
15. Ordinary fixed-size arrays are sufficient for the tested representation.
16. A consumer-local ordinary aggregate is sufficient for grouping stages.
17. No dedicated CTFE palette API is justified by phase-C evidence.
18. No dedicated public palette container is justified by phase-C evidence.
19. No public API is frozen.

---

## C.20 Not established by R0.12-C

R0.12-C does not yet establish:

- a universal numerical tolerance;
- exact runtime/CTFE equality after transcendental floating-point operations;
- ULP guarantees;
- compiler-independent bit patterns;
- compile-time cost/scaling behavior;
- larger-cardinality behavior;
- pathological CTFE resource behavior;
- final edge/property coverage;
- final public palette API;
- final production template ergonomics.

Those remain later R0.12 or R0.13 concerns.

---

## C.21 Phase-C status

R0.12-C is complete.

R0.12-D follows below.

R0.12 as a whole remains in progress.

---

# R0.12-D — Coarse CTFE cost

**Status:** VALIDATED
**Phase:** R0.12-D

R0.12-D tests only whether the palette construction pipeline shows an obvious
pathological compile-time cost increase at representative palette sizes.

It is not a compiler benchmark and does not establish a public performance
guarantee.

---

## D.1 Measurement shape

The cost experiment is isolated from the R0.12 A/B/C runtime test harness.

It uses compile-only probes containing the same general pipeline:

```text
compile-time seeds and schedules
        ↓
raw OKLCH palette
        ↓
Ray Trace gamut mapping
        ↓
linear-sRGB result
        ↓
encoded sRGB result
```

The measured scalar type is:

```text
double
```

The tested palette sizes are:

| Probe | Families | Tones/family | Total tones |
|---|---:|---:|---:|
| baseline | — | — | 0 |
| 15 | 3 | 5 | 15 |
| 60 | 6 | 10 | 60 |
| 240 | 12 | 20 | 240 |

Thus:

```text
15 → 60  = 4× more tones
60 → 240 = 4× more tones
```

The baseline parses and compiles the common probe code but performs no palette
CTFE instantiation.

---

## D.2 Compilers

The final measurement used:

```text
DMD 2.111.0
LDC 1.41.0
based on DMD v2.111.0
LLVM 19.1.7
```

All baseline and palette probes compiled successfully under both compilers.

No probe compile failure was observed.

---

## D.3 Measurement protocol

The retained measurement script is:

```text
experiments/r0_12_palette_ctfe/cost/measure.sh
```

Protocol:

```text
1 warm-up compile per compiler and probe size

then:

5 interleaved measurement rounds

each round:
    DMD  baseline, 15, 60, 240
    LDC  baseline, 15, 60, 240
```

The measured quantities are:

```text
wall-clock compile time
peak RSS
```

using GNU `/usr/bin/time`.

The compiler invocation is compile-only.

The final raw data contains:

```text
2 compilers
× 4 probe sizes
× 5 measured runs
= 40 measurements
```

plus one TSV header line.

Observed file length:

```text
41 lines
```

---

## D.4 Retained raw data

Raw measurements are stored in:

```text
experiments/r0_12_palette_ctfe/cost/measurements.tsv
```

SHA-256:

```text
6f4da85b74b8e6377cb2d1f64a37bc83455b429c2cdc17d7f3b84a36387a8523
```

The original measurement data was not regenerated after the reporting-script
path bug was fixed.

Only the summary path handling in `measure.sh` was repaired.

---

## D.5 Probe hashes

Final probe hashes:

```text
probe_common.d
5d8f2c2f3f0fafc5268c72edf93ed94c5710579eb26921278647c8493f6a1d78

probe_baseline.d
c3552efb68b2f185db954c529479befa701f242da07509066078e1b66e2f9fde

probe_15.d
ec1d2e2dc57cf23f2e880885f828fe15ec87cf5ddebb7ad9c045efab09291701

probe_60.d
fb920d0c8fe0b71423af5b007fae9a97585dd441530d6c4cc372803274b7eee5

probe_240.d
7954330844df543c63051855eb9dba653bc9bb847073ea0aa9db996149100b21
```

Final measurement-script SHA-256:

```text
e835200a1d73f8eb8f2c39020a87610b6ad4e347d411d4f84b8a6fcde9bef01d
```

---

## D.6 DMD measurements

Median results:

| Probe | Wall median | Wall range | Extra vs baseline | RSS median | RSS range | Extra RSS |
|---|---:|---:|---:|---:|---:|---:|
| baseline | 0.020 s | 0.020–0.030 s | 0.000 s | 22,536 KiB | 22,484–22,596 | 0 KiB |
| 15 | 0.040 s | 0.040–0.050 s | +0.020 s | 28,484 KiB | 28,432–28,532 | +5,948 KiB |
| 60 | 0.050 s | 0.050–0.060 s | +0.030 s | 32,216 KiB | 32,128–32,296 | +9,680 KiB |
| 240 | 0.110 s | 0.110–0.120 s | +0.090 s | 47,300 KiB | 47,264–47,348 | +24,764 KiB |

For DMD, increasing from 15 to 240 tones means:

```text
16× more palette tones
```

while the measured median total compile time changes from:

```text
0.040 s → 0.110 s
```

and median peak RSS from:

```text
28,484 KiB → 47,300 KiB
```

No abrupt cost discontinuity is observed.

---

## D.7 LDC measurements

Median results:

| Probe | Wall median | Wall range | Extra vs baseline | RSS median | RSS range | Extra RSS |
|---|---:|---:|---:|---:|---:|---:|
| baseline | 0.050 s | 0.050–0.050 s | 0.000 s | 87,904 KiB | 87,792–88,116 | 0 KiB |
| 15 | 0.080 s | 0.070–0.080 s | +0.030 s | 99,776 KiB | 99,720–99,924 | +11,872 KiB |
| 60 | 0.090 s | 0.090–0.100 s | +0.040 s | 103,688 KiB | 103,396–103,784 | +15,784 KiB |
| 240 | 0.160 s | 0.150–0.170 s | +0.110 s | 119,364 KiB | 119,284–119,380 | +31,460 KiB |

For LDC, increasing from 15 to 240 tones likewise means:

```text
16× more palette tones
```

while median total compile time changes from:

```text
0.080 s → 0.160 s
```

and median peak RSS from:

```text
99,776 KiB → 119,364 KiB
```

Again, no abrupt cost discontinuity is observed.

---

## D.8 Baseline-adjusted interpretation

Because the absolute compile times are very small, ratios against the baseline
can exaggerate differences.

The more useful coarse observation is the additional median cost relative to
the no-palette-CTFE baseline.

At 240 tones:

```text
DMD:
    +0.090 s
    +24,764 KiB peak RSS

LDC:
    +0.110 s
    +31,460 KiB peak RSS
```

Those values are machine- and compiler-specific measurements.

They are not proposed budgets or guarantees.

---

## D.9 Scaling interpretation

The test deliberately increases palette cardinality geometrically:

```text
15
60
240
```

Each step contains four times as many tones.

Neither compiler shows a corresponding pathological jump in measured compile
time or peak RSS.

In particular, the second 4× cardinality increase:

```text
60 → 240
```

changes median total compile time by:

```text
DMD:
    0.050 s → 0.110 s

LDC:
    0.090 s → 0.160 s
```

and median peak RSS by:

```text
DMD:
    32,216 KiB → 47,300 KiB

LDC:
    103,688 KiB → 119,364 KiB
```

This is sufficient for the R0.12 question:

```text
no obvious pathological CTFE scaling was observed up to 240 tones
```

---

## D.10 Why the experiment stops at 240 tones

R0.12-D is intended only as a coarse guard against obviously pathological
implementation choices.

The 240-tone probe already exercises:

```text
12 families
× 20 tones
= 240 complete compile-time color pipelines
```

and follows two successive 4× increases from the initial 15-tone case.

The observed behavior does not justify expanding R0.12 into a large compiler
benchmark study.

A larger 960-tone probe is therefore not required by the current evidence.

---

## D.11 Measurement limitations

The experiment does not establish asymptotic complexity.

Important limitations include:

```text
one machine
one operating environment
DMD 2.111.0
LDC 1.41.0
double only
compile-only probes
five measured runs
wall-clock resolution of approximately 0.01 s
```

Compiler startup, parsing, semantic analysis, CTFE, object generation and other
compile work all contribute to the measured wall time and RSS.

The baseline partially accounts for fixed compiler/probe overhead but does not
isolate CTFE instruction cost in a laboratory sense.

Therefore the measurements support only a coarse engineering conclusion.

---

## D.12 Performance-policy boundary

R0.12-D does not establish:

```text
a compile-time performance SLA
a maximum acceptable palette size
a universal CTFE budget
a DMD-versus-LDC performance ranking
an asymptotic complexity guarantee
a compiler-specific optimization
```

Compiler-specific optimization remains subject to the separate performance and
compiler-policy work.

---

## D.13 Phase-D conclusions

R0.12-D supports the following conclusions:

1. The isolated complete palette pipeline compiles successfully at 15, 60 and
   240 tones.
2. Both DMD 2.111.0 and LDC 1.41.0 successfully evaluate the tested CTFE
   probes.
3. Two successive 4× increases in palette cardinality do not expose an obvious
   pathological compile-time jump.
4. Peak RSS increases remain moderate across the tested sizes.
5. Compile-time increases remain moderate across the tested sizes.
6. The 240-tone case remains operationally small in this environment.
7. No special CTFE palette representation is justified by cost evidence.
8. No compiler-specific implementation path is justified by cost evidence.
9. A larger R0.12 compiler benchmark is not required by the observed data.
10. The result is coarse engineering evidence, not a performance guarantee.
11. No public API is frozen.

---

## D.14 Not established by R0.12-D

R0.12-D does not establish:

- asymptotic time complexity;
- asymptotic memory complexity;
- behavior at arbitrarily large palette sizes;
- other CPU architectures;
- other operating systems;
- other compiler versions;
- float-versus-double CTFE cost comparison;
- incremental-build behavior;
- full application build cost;
- a compile-time performance contract.

---

## D.15 Phase-D status

R0.12-D is complete.

The next phase is:

```text
R0.12-E — Integration and edge properties
```

R0.12 as a whole remains in progress.

---

# R0.12-E — Integration and edge properties

## E.1 Purpose

R0.12-E exercises the already validated palette-composition pieces as one
integrated pipeline and checks edge properties that are easy to miss when
testing only representative multi-tone palettes.

The phase does not introduce new color mathematics.

It exercises:

```text
raw schedule construction
→ explicit gamut mapping
→ explicit target-space conversion
→ caller-selected validation
```

with particular attention to:

```text
1 × 1 palette cardinality
explicit hue preservation
achromatic / zero-chroma input
in-gamut zero-iteration mapping
known out-of-gamut active mapping
family independence
family permutation
cross-family measurements
runtime / CTFE integration
compiler-baseline behavior
```

No application semantic roles are introduced.

---

## E.2 Final source

The final validated experiment source is:

```text
experiments/r0_12_palette_ctfe/source/app.d
```

SHA-256:

```text
9baf0b3de9778d025104e26021e789c15eada78d2075b7a085185a0c2b82fd6f
```

The complete post-workaround compiler matrix was run against this unchanged
source.

---

## E.3 Integration checks

R0.12-E contains 13 checks per scalar type.

Both:

```text
float
double
```

are exercised, for a total of:

```text
26 checks per compiler/build run
```

The checks cover the following integration properties.

### Smallest non-empty palette

A:

```text
1 family × 1 tone
```

palette preserves the explicit raw components:

```text
L = 0.5
C = 0.0
h = 725°
```

The stored hue is not implicitly normalized.

### In-gamut mapping path

The achromatic singleton maps successfully with:

```text
iterations = 0
```

and remains in gamut after mapping and encoding.

### Active out-of-gamut mapping path

The independently established high-chroma yellow case is exercised through the
complete bundle pipeline.

Its mapping:

```text
succeeds
and
uses more than zero iterations
```

so the integrated pipeline does not silently turn the known out-of-gamut case
into an in-gamut no-op.

### Family independence

Changing a chroma value in one family changes that family while leaving the
other raw, mapped and encoded families unchanged under exact structural
comparison.

### Family permutation

Permuting the family inputs only permutes the corresponding raw, mapped and
encoded family results.

No cross-family state is introduced by palette construction.

### Cross-family measurement

Caller-selected contrast and OKLab-distance pairs may reference tones from
different families without introducing semantic palette roles.

The measurement primitives remain independent of the caller's acceptance
policy.

---

## E.4 Initial DMD runtime anomaly

The original Phase-E implementation returned and passed nested static arrays by
value through generic helper functions such as:

```text
composeRawPalette
mapPaletteRayTrace
encodeMappedPalette
buildPaletteBundle
```

The first full Phase-E run exposed a compiler-dependent runtime anomaly.

With DMD 2.111.0:

```text
Debug:
    R0.12-E = 24 PASS, 2 FAIL

Release:
    R0.12-E = 24 PASS, 2 FAIL
```

The failures were both the 1 × 1 raw-palette preservation check:

```text
float
double
```

The remaining Phase-E checks passed.

LDC 1.41.0 passed the same source.

This was therefore investigated before accepting Phase E.

---

## E.5 Compiler-bug isolation

The investigation was intentionally reduced beyond the color-d experiment.

The resulting reproducer set is stored under:

```text
experiments/r0_12_palette_ctfe/compiler_bug/
```

The most reduced return reproducer contains:

```d
struct S
{
    float a;
    float b;
    float c;
}

S[1][1] make()
{
    S[1][1] result;
    result[0][0] = S(0.5f, 0.0f, 725.0f);
    return result;
}
```

No:

```text
color-d dependency
template
CTFE
gamut mapping
color conversion
```

is required to reproduce the naked nested-static-array return failure.

The minimal naked-return reproducer fails at runtime under all controlled DMD
versions:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0
```

in both Debug and Release.

The corresponding controlled LDC versions:

```text
LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
```

produce the expected values.

A separate parameter-only reproducer passes on all tested compilers.

Therefore ordinary static-array parameter reading alone is not sufficient to
reproduce the defect.

---

## E.6 Additional ABI/code-generation observations

The investigation found several distinct behaviors rather than one simple
"static arrays are broken" rule.

### Simple non-generic compatibility test

For a simple non-generic `S[1][1]` case under DMD 2.111.0 through 2.113.0:

```text
naked by-value return    FAIL
out destination          PASS
ref destination          PASS
simple struct wrapper    PASS
```

LDC passes all variants.

### Generic wrapper test

A generic wrapper is not sufficient for the older DMD baseline.

For DMD 2.111.0 through 2.112.1, generic:

```text
bare return
boxed return
bundle return
```

may all produce incorrect runtime values.

DMD 2.113.0 fixes the tested generic boxed/bundle cases, while the naked
`float[1][1]`-style return remains broken.

### Generic `ref` output with by-value static-array inputs

Changing only the output to caller-owned `ref` storage is also insufficient.

The tested generic form with:

```text
ref output
+
by-value static-array inputs
```

segfaults at runtime under:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
```

in both Debug and Release.

The same test succeeds under DMD 2.113.0 and all tested LDC versions.

### Generic `ref` output with `ref const` static-array inputs

The stable common form found by the experiment is:

```text
output:
    ref

static-array inputs:
    ref const
```

This form passes in both Debug and Release under every controlled compiler:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0

LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
```

for both:

```text
float
double
```

This is the compatibility form used by the final R0.12-E runtime pipeline.

---

## E.7 Compatibility implementation

The experiment now provides caller-owned helpers:

```text
composeRawFamilyInto
composeRawPaletteInto

mapFamilyRayTraceInto
mapPaletteRayTraceInto

encodeMappedFamilyInto
encodeMappedPaletteInto

buildPaletteBundleInto
```

Their relevant transport convention is:

```text
result:
    ref

static-array input:
    ref const
```

The mathematical operations themselves are unchanged.

The original value-returning helpers remain research wrappers and continue to
be useful for CTFE and comparison experiments.

They are not established by R0.12-E as a generally runtime-safe API for the
entire compiler baseline.

---

## E.8 Why no compiler switch is required here

A compiler/version-specific branch is not necessary for correctness in R0.12.

The same caller-owned transport form works on:

```text
all tested DMD versions
and
all tested LDC versions
```

from the project baseline upward.

The preferred policy is therefore:

```text
use one correct common implementation where practical
```

rather than introducing a compiler version branch merely because one compiler
has a defective alternative ABI/code-generation path.

Compiler-specific paths remain legitimate when later evidence demonstrates that
they are necessary for:

```text
correctness
or
material performance
```

Such paths must be justified by measurements or a reproduced compiler defect.

R0.12 does not establish a performance reason to add such a switch.

---

## E.9 Final compiler matrix

Because Phase E exposed a concrete compiler-dependent runtime problem, the
correctness matrix was expanded beyond the original baseline.

The final unchanged source was tested with:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release

DMD 2.112.0  Debug
DMD 2.112.0  Release

DMD 2.112.1  Debug
DMD 2.112.1  Release

DMD 2.113.0  Debug
DMD 2.113.0  Release

LDC 1.41.0   Debug
LDC 1.41.0   Release

LDC 1.42.0   Debug
LDC 1.42.0   Release

LDC 1.43.0   Debug
LDC 1.43.0   Release
```

Every run reports:

```text
R0.12-A: 18 PASS, 0 FAIL
R0.12-B: 28 PASS, 0 FAIL
R0.12-C: 22 PASS, 0 FAIL
R0.12-E: 26 PASS, 0 FAIL
```

Therefore each compiler/build run contains:

```text
94 PASS
0 FAIL
```

Across the 14 final runs:

```text
1,316 PASS
0 FAIL
```

The project correctness baseline is therefore preserved for the tested
compiler matrix.

The common implementation form was verified from the baseline through:

```text
DMD 2.111.0 → DMD 2.113.0
LDC 1.41.0  → LDC 1.43.0
```

on the tested architecture.

Future compiler releases remain subject to the same baseline-support policy but
are not claimed as verified by R0.12-E.

---

## E.10 CTFE boundary

The compiler defect investigated in Phase E is a runtime code-generation /
calling-convention observation.

The relevant compile-time constructions and static assertions also compiled
successfully while older DMD runtime variants were producing incorrect values.

R0.12 therefore does not identify CTFE evaluation itself as the cause of the
Phase-E corruption.

The value-returning construction remains suitable for the compile-time
experiments where it is fully evaluated during compilation.

---

## E.11 Numerical-tolerance boundary

R0.12-E does not alter the Phase-C observation that runtime and CTFE floating
point results may differ slightly after gamut mapping and encoding.

No epsilon or tolerance policy is introduced here.

That subject remains assigned to:

```text
R0.13 — tolerance and reference strategy
```

and should be checked across the supported compiler baseline rather than only
one compiler/version.

---

## E.12 Architectural implications

The final Phase-E evidence supports the following architecture:

```text
scalar/color mathematical primitives
+
ordinary fixed-size arrays
+
explicit caller-owned policy
+
ABI-safe internal transport where required
```

No semantic `Palette`, `Theme`, `PaletteBuilder` or `ThemeBuilder` abstraction
is required by the observed mathematics.

The compiler workaround does not create new palette semantics.

It is an implementation/transport concern.

---

## E.13 Phase-E conclusions

R0.12-E supports the following conclusions:

1. The smallest non-empty 1 × 1 palette is a relevant integration edge case.
2. Explicit raw hue values are preserved without implicit normalization.
3. An in-gamut achromatic singleton takes the successful zero-iteration mapping
   path.
4. The known out-of-gamut case takes an active successful Ray Trace path.
5. Editing one family does not perturb independent families.
6. Family permutation only permutes the corresponding results.
7. Cross-family contrast and distance measurement compose without semantic
   palette roles.
8. Raw, mapped and encoded representations remain separate.
9. The original DMD failures are compiler/runtime transport effects rather than
   failures of the color mathematics.
10. Naked and generic by-value static-array transport cannot be treated as
    baseline-safe merely because it compiles.
11. Caller-owned `ref` output plus `ref const` static-array inputs provides one
    common tested path across DMD 2.111.0–2.113.0 and LDC 1.41.0–1.43.0.
12. No compiler switch is required for correctness in the current
    implementation.
13. Compiler switches remain available when separately justified by correctness
    or measured performance.
14. No new palette semantic abstraction is justified.
15. No numerical tolerance policy is introduced.
16. No public API is frozen.

---

## E.14 Not established by R0.12-E

R0.12-E does not establish:

- the exact internal root cause inside the DMD backend;
- behavior on architectures other than the tested x86-64 environment;
- behavior on operating systems other than the tested environment;
- that every possible static-array shape has the same compiler behavior;
- that value-returning wrappers are suitable as a production runtime API on
  the full baseline;
- a performance advantage for either ABI form;
- a compiler-specific optimization policy;
- a universal numerical epsilon;
- application theme semantics;
- a public palette API.

---

## E.15 Phase-E status

R0.12-E is complete.

The final Phase-E implementation passes the complete expanded compiler matrix
from the established baseline upward.

R0.12 as a whole may now proceed to synthesis / closeout.
