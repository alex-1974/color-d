# color-d — Technical Specification

**Status:** Draft / Research-derived specification  
**Project:** `color-d`  
**Language:** D  
**Primary consumers:** OSM/geospatial editor, `imagery-d`  
**Scope:** Color mathematics, conversion, compositing, perceptual operations and palette primitives

---

## 1. Purpose

`color-d` is a small, type-safe, allocation-free color mathematics library for D.

Its central design principle is:

> A color value always belongs to a known color space, and operations that change color-space semantics are explicit.

The library provides mathematical building blocks for applications that need correct color representation, conversion, interpolation, compositing, contrast analysis and perceptual manipulation.

Primary initial consumers are:

- the planned D OSM/geospatial editor;
- `imagery-d`;
- GUI and rendering code built on top of those projects.

The library itself remains independent of:

- OSM;
- GUI frameworks;
- image formats;
- rendering APIs;
- OpenGL, Vulkan or WebGPU;
- application-specific theme semantics.

---

# 2. Design goals

`color-d` shall provide:

- explicit, statically typed color spaces;
- a strict distinction between encoded sRGB and linear-light sRGB;
- compact value types suitable for hot paths;
- generic `float` and `double` computation;
- packed 8-bit storage types;
- modern perceptual color spaces centered around Oklab and OKLCH;
- correct linear-light alpha compositing;
- explicit gamut testing, clipping and gamut mapping;
- explicit interpolation semantics;
- relative luminance and contrast computation;
- palette and tone-scale primitives;
- compile-time evaluation where technically possible;
- predictable data layout suitable for interoperability;
- `@safe`, `pure`, `nothrow` and `@nogc` mathematical operations wherever applicable.

The public API should be small, orthogonal and difficult to misuse.

---

# 3. Non-goals

`color-d` is not an image-processing library.

The core library will not implement:

- resizing;
- convolution;
- blur;
- image codecs;
- raster tiling;
- image caching;
- image I/O.

Those belong in `imagery-d` or other consumers.

The initial library will also not attempt to become a full color-management system.

Out of scope for v0.1:

- ICC profile processing;
- CMYK production workflows;
- printer/device profiling;
- rendering intents;
- prepress;
- HDR pipelines;
- complex display calibration;
- CSS parsing and serialization;
- application-specific GUI themes.

---

# 4. Architectural principles

## 4.1 Color space is part of the type

The library shall not represent mathematical colors as anonymous component arrays such as:

```d
float[3]
```

for public APIs.

Instead:

```d
SRgb!float
LinearSRgb!float
XyzD65!float
Oklab!float
Oklch!float
Hsl!float
Hsv!float
```

This prevents semantically incompatible values from being accidentally mixed.

For example:

```d
SRgbf encoded;
LinearSRgbf linear;
```

must be distinct types despite having the same physical component layout.

---

## 4.2 Color-space conversion is explicit

Implicit conversions between different color spaces are prohibited.

Preferred API:

```d
auto linear = rgb.toLinear;
auto lab    = rgb.toOklab;
auto lch    = lab.toOklch;
```

Conversions shall not normally be exposed as implicit constructors or generic `opCast` operations.

The source code should visibly show when color semantics change.

---

## 4.3 Storage and computation are different concerns

Packed storage types:

```d
SRgb8
SRgba8
```

are distinct from mathematical working types:

```d
SRgb!float
LinearSRgb!float
Oklab!float
```

Storage types are bounded representations intended for:

- files;
- UI interoperability;
- textures;
- compact tables;
- renderer upload.

Computational types use floating-point values and may temporarily contain values outside the nominal display gamut.

---

# 5. Scalar model

Computational color types are generic over floating-point scalar type:

```d
struct SRgb(T);
struct LinearSRgb(T);
struct XyzD65(T);
struct Oklab(T);
struct Oklch(T);
struct Hsl(T);
struct Hsv(T);
```

with constraints limiting `T` to supported floating-point types.

Convenience aliases should be provided:

```d
alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;

alias Oklabf      = Oklab!float;
alias Oklabd      = Oklab!double;
```

Expected use:

- `float` for normal rendering, GUI and large arrays;
- `double` for high-precision computation, validation and reference tests.

Integer color representations remain separate explicit storage types.

---

# 6. Initial public color spaces

## 6.1 Required for v0.1

### Encoded sRGB

```d
SRgb!T
SRgb8
SRgba8
```

Represents standard nonlinear sRGB encoding.

---

### Linear-light sRGB

```d
LinearSRgb!T
```

This is the primary space for:

- physical RGB arithmetic;
- alpha compositing;
- luminance;
- selected interpolation operations.

It must never be interchangeable with encoded sRGB.

---

### XYZ D65

```d
XyzD65!T
```

XYZ D65 is public rather than merely an internal conversion node.

It provides a stable bridge for:

- sRGB;
- future Display-P3;
- future Rec.2020;
- Oklab;
- scientific consumers;
- standards/reference tests.

---

### Oklab

```d
Oklab!T
```

Oklab is the primary rectangular perceptual color space.

Primary uses:

- perceptual interpolation;
- color-distance calculations;
- theme generation;
- UI color manipulation.

---

### OKLCH

```d
Oklch!T
```

OKLCH is the primary polar perceptual color space.

Primary uses:

- tone scales;
- shades;
- hue-preserving transformations;
- semantic palette construction;
- gamut mapping.

---

### HSL

```d
Hsl!T
```

Provided mainly for:

- CSS/UI interoperability;
- legacy workflows.

HSL is not the preferred space for perceptual theme manipulation.

---

### HSV / HSB

```d
Hsv!T
```

Provided mainly for:

- conventional color pickers;
- familiar user-facing manipulation.

HSV is not used as the basis for perceptually uniform theme generation.

---

# 7. Deferred color spaces

Not required for the first public implementation:

```text
XYZ D50
CIELAB
CIELCh
Display-P3
linear Display-P3
Rec.2020
Okhsl
Okhsv
HDR-specific spaces
```

Display-P3 is expected to be the first major wide-gamut extension after the initial sRGB-centered core.

CIELAB/LCh remain useful for standards interoperability and historical Delta-E algorithms, but are not required by the initial OSM/GUI consumers.

---

# 8. Range and gamut semantics

Computational color values shall not automatically clamp themselves to displayable component ranges.

For example:

```d
SRgbf(1.12f, -0.04f, 0.70f)
```

is a valid intermediate mathematical value.

This is necessary for:

- loss-minimizing round trips;
- color-space transformations;
- wide-gamut conversion;
- perceptual transformations;
- gamut mapping.

Therefore the following concepts are separate:

```d
inGamut(color)
clip(color)
gamutMap(color)
```

### `inGamut`

Tests whether a color lies inside a target gamut.

It does not modify the value.

### `clip`

Performs explicit hard component clipping.

It is mathematically simple but may alter hue and perceived color.

### `gamutMap`

Performs explicit perceptual gamut mapping.

It must never happen silently as part of `toSRgb()`.

---

# 9. NaN and infinity policy

The mathematical core should not silently normalize or repair invalid floating-point values.

Operations may provide diagnostics such as:

```d
isFinite(color)
isInGamut(color)
```

but NaN and infinity should remain visible to the caller unless an explicitly named operation handles them.

CSS-specific concepts such as missing components expressed through `none` are parser-layer semantics and do not belong in the mathematical core types.

---

# 10. Conversion API

Expected primitive operations include:

```d
toLinear
toSRgb
toXyzD65
toOklab
toOklch
toHsl
toHsv
```

Conversions should be allocation-free.

Whenever practical they should be:

```d
@safe
pure
nothrow
@nogc
```

Round-trip behavior must be specified and tested independently for `float` and `double`.

---

# 11. Alpha model

Alpha is a first-class concern.

Rather than defining a separate alpha-bearing type for every color space, the preferred architecture is an orthogonal wrapper:

```d
Alpha!Color
```

Conceptually:

```d
Alpha!(SRgbf)
Alpha!(LinearSRgbf)
Alpha!(Oklabf)
```

A distinct representation shall be considered for premultiplied alpha:

```d
Premultiplied!Color
```

or an equivalent strongly typed model.

Straight and premultiplied alpha must not be silently interchangeable.

---

# 12. Alpha compositing

Normal source-over compositing shall operate in linear-light RGB.

Typical preferred working type:

```d
Premultiplied!(LinearSRgbf)
```

Core operations may include:

```d
premultiplyAlpha
unpremultiplyAlpha
composite
```

The implementation shall avoid gamma-space compositing.

Application renderers may store other representations, but the library's mathematically correct reference behavior uses linear-light RGB.

---

# 13. Interpolation

The library shall not claim that one interpolation space is universally correct.

Different semantics require different spaces:

- encoded sRGB: compatibility/legacy behavior;
- linear sRGB: physical RGB/light interpolation;
- Oklab: perceptually smooth interpolation;
- OKLCH: hue/chroma-aware interpolation.

The lowest-level primitive should preferably operate on matching types:

```d
interpolate(a, b, t)
```

Example:

```d
auto mixed =
    interpolate(
        a.toOklab,
        b.toOklab,
        0.5
    ).toSRgb;
```

A later convenience API may select the space through an explicit policy.

---

# 14. Polar hue interpolation

Polar color spaces require explicit hue interpolation rules.

Provide a policy equivalent to:

```d
enum HuePath
{
    shorter,
    longer,
    increasing,
    decreasing
}
```

The caller must be able to select the interpolation route when required.

Default behavior may follow the shorter angular path.

---

# 15. Perceptual manipulation

Core operations should remain mathematically explicit.

Preferred primitives:

```d
withLightness
withChroma
withHue
```

For example:

```d
auto brighter = color.toOklch.withLightness(0.82);
```

Generic convenience names such as:

```d
lighten()
darken()
```

should not be added until their semantics are unambiguous and formally documented.

They must not silently mean HSV/HSL manipulation.

---

# 16. Relative luminance and contrast

WCAG-2 relative luminance and general colorimetric XYZ-D65 Y are distinct
operations and must not be silently aliased.

The initial accessibility-oriented measurement is explicitly sRGB-specific and
WCAG-2-specific.

Research naming candidates include:

```d
wcag2RelativeLuminance
wcag2ContrastRatio
```

These names remain provisional until consumer validation.

Generic names such as:

```d
relativeLuminance
contrastRatio
```

should not be frozen while multiple luminance and contrast concepts may coexist.

## 16.1 WCAG-2 relative luminance

WCAG-2 relative luminance uses the published WCAG coefficients:

```text
0.2126
0.7152
0.0722
```

after sRGB transfer decoding.

Encoded sRGB channel values must never be inserted directly into the luminance
formula without decoding.

Within the valid sRGB domain, the already validated color-d sRGB transfer
implementation may be reused.

The WCAG coefficients must not be replaced by the more precise XYZ-D65 matrix
coefficients merely because the resulting values are numerically close.

## 16.2 Valid measurement domain

A standards-facing WCAG-2 measurement requires finite sRGB or linear-sRGB
components in:

```text
0 <= component <= 1
```

Extended color-d values outside this domain remain useful mathematical color
values but are not valid WCAG-2 measurements.

Standards-facing WCAG operations therefore require explicit domain validation.

They must not silently:

- clip;
- gamut-map;
- repair NaN or infinity;
- reinterpret extended color values as valid WCAG input.

Unchecked arithmetic may exist internally where useful, but must not be
presented as a valid standards measurement for invalid-domain input.

## 16.3 Contrast ratio

For valid WCAG-2 relative luminances:

```text
L1 >= L2

contrast = (L1 + 0.05) / (L2 + 0.05)
```

The valid-domain range is:

```text
1 : 1
```

through:

```text
21 : 1
```

Contrast measurement is distinct from accessibility pass/fail policy.

Context-dependent concepts such as:

```text
AA
AAA
large text
normal text
non-text UI
font size
font weight
```

belong in a higher-level accessibility or theme layer.

## 16.4 Alpha

An unresolved alpha color does not have one standalone WCAG contrast ratio.

The actual rendered color must be resolved against its background before
ordinary contrast measurement.

WCAG measurement must not silently infer a background or introduce hidden
compositing policy.

Premultiplied storage must not be interpreted directly as ordinary RGB input
for contrast measurement.

## 16.5 Invalid-result representation

R0.9 compared several checked-result representations.

A two-field result:

```d
struct Measurement(T)
{
    T value;
    bool valid;
}
```

is not the preferred candidate because DMD 2.111 showed a large,
reproducible `double` code-generation regression for this representation.

A compact single-scalar measurement is the preferred research candidate:

```text
finite scalar -> valid measurement
NaN           -> invalid measurement
```

with validity derived from the scalar state.

This preserves value semantics and keeps the representation at:

```text
float  -> 4 bytes
double -> 8 bytes
```

A future production type must control construction so callers cannot create
arbitrary supposedly valid measurements outside the defined result domain.

A `try(..., ref T)` form remains a valid alternative if later consumer
evidence favors it.

No result representation is frozen during R0.

## 16.6 Performance and compiler evidence

R0.9 found that the compact scalar result and `try(..., ref T)` have similar
encoded-sRGB and contrast performance on the measured system.

DMD 2.111 showed a large regression specifically for the two-field
`{ double, bool }` result representation.

Explicit `pragma(inline, true)` did not remove that regression.

Generated-code inspection showed that the relative-luminance benchmark paths
were already integrated into the benchmark loop, so the observed difference
cannot be explained simply by one candidate failing to inline.

This is compiler/version-specific evidence and must not be generalized into a
universal D ABI rule.

## 16.7 Future contrast metrics

WCAG 3 / APCA-style contrast models remain separate future research.

They must use explicit separate semantics and must not silently redefine the
meaning of a WCAG-2 operation.

---

# 17. Color difference

The API should avoid a generic ambiguous:

```d
deltaE()
```

when multiple algorithms exist.

Preferred explicit names:

```d
deltaEOK
deltaE76
deltaE2000
```

For the initial version only `deltaEOK` is required.

CIELAB-based Delta-E variants may be added when CIELAB support becomes a concrete requirement.

---

# 18. Gamut mapping

Gamut membership, clipping and perceptual gamut mapping are distinct
operations.

Ordinary color-space conversion must not implicitly clip or gamut-map
extended values.

The initial concrete target gamut is sRGB.

## 18.1 Gamut membership

Strict gamut membership is a diagnostic query.

For the initial sRGB target, encoded sRGB and linear sRGB use the same
component-domain membership condition:

```text
0 <= r <= 1
0 <= g <= 1
0 <= b <= 1
```

A numerical tolerance around the boundary is a separate numerical-policy
concern. It must not redefine the geometric gamut.

Non-finite values are not considered in gamut and are not silently repaired.

## 18.2 Clipping

Hard component clipping is an explicit target-space operation.

It is distinct from perceptual gamut mapping and therefore must not be a
`GamutMapMethod` variant.

Clipping may alter hue and perceived color, but remains useful where the
caller explicitly requests hard target-coordinate saturation.

## 18.3 Perceptual gamut mapping

The architecture shall allow multiple explicit perceptual mapping methods.

The initial validated candidates are:

```d
enum GamutMapMethod
{
    // names provisional
    localMinde,
    rayTrace
}
```

No public default mapping method is frozen at this stage.

### Local MINDE

Local MINDE remains the standards-oriented / perceptual reference candidate.

R0.8 observed:

- adaptive iterative search;
- useful perceptual/reference behavior;
- substantially higher dynamic cost than Ray Trace on the measured system.

### Ray Trace

Ray Trace remains the bounded-cost / performance-oriented candidate.

R0.8 observed:

- a fixed small iteration budget;
- substantially fewer dynamic instructions and branches than Local MINDE;
- predictable bounded work;
- no requirement for an external lookup table.

The validated optimized implementation can avoid repeated `atan2` in the
iterative projection path.

The RGB-cube intersection helper is also a justified explicit-inline
candidate based on timing, hardware-counter and generated-code evidence.

These performance results are implementation evidence from the measured
x86-64/LDC system, not universal cross-platform guarantees.

## 18.4 Fast-path and alpha semantics

Already in-gamut colors shall take the identity / fast path and must not enter
the iterative mapping process.

Per-color gamut mapping transforms color coordinates, not alpha. Alpha is
preserved.

A premultiplied compositing representation must not be interpreted directly
as ordinary RGB coordinates for gamut mapping.

## 18.5 Policy boundary

The mapping method should remain explicit wherever policy matters until
consumer evidence establishes whether a default is desirable.

EdgeSeeker remains deferred.

Per-color scalar gamut mapping in `color-d` is not a complete photographic
rendering intent. Image-wide rendering, spatial adaptation and raster-wide
policy remain consumer responsibilities, primarily in `imagery-d`.

The strategy must remain replaceable and must never become implicit behavior
of ordinary conversions.

---

# 19. Tone scales and palettes

`color-d` should contain low-level perceptual palette primitives because there are concrete consumers in GUI styling and map rendering.

Possible interface:

```d
toneScale(base, parameters)
```

or:

```d
perceptualScale(base, range, steps)
```

The algorithm should use OKLCH rather than RGB scaling or HSV `value` manipulation.

A tone-scale generator may:

1. vary perceptual lightness;
2. preserve hue where possible;
3. optionally adjust chroma;
4. apply explicit gamut mapping;
5. produce final target-space colors.

---

# 20. Theme semantics remain outside color-d

The library does not know concepts such as:

```text
accent
warning
success
selected
hovered
road.primary
building.residential
```

Those are application-level semantics.

Dependency direction:

```text
color-d
    ↓
theme/design-token layer
    ↓
OSM style engine
    ↓
renderer
```

---

# 21. Compile-time evaluation

Compile-time evaluation is a first-class design objective.

All deterministic mathematical core operations should be written such that they can execute both:

- at runtime;
- during D CTFE;

where the language and standard library permit it.

This includes, where practical:

```text
sRGB transfer functions
sRGB ↔ linear sRGB
sRGB ↔ XYZ D65
XYZ ↔ Oklab
Oklab ↔ OKLCH
relative luminance
contrast
interpolation
tone generation
gamut testing
gamut mapping
deltaEOK
```

CTFE capability should be tested explicitly.

Example:

```d
static assert({
    enum c = SRgbf(0.2f, 0.4f, 0.8f);
    enum l = c.toOklab;
    enum r = l.toSRgb;

    return approxEqual(c, r);
}());
```

---

# 22. Compile-time GUI theme generation

Built-in themes should be able to be generated fully during compilation.

Example application architecture:

```d
enum ThemeSeed seed = ...;

static immutable Theme lightTheme =
    makeTheme(seed, ThemeMode.light);

static immutable Theme darkTheme =
    makeTheme(seed, ThemeMode.dark);

static immutable Theme highContrastTheme =
    makeTheme(seed, ThemeMode.highContrast);
```

The compiler may perform:

```text
semantic seed colors
    ↓
OKLCH tone generation
    ↓
chroma adjustment
    ↓
gamut mapping
    ↓
contrast selection
    ↓
hover/focus/selection derivation
    ↓
sRGB/linear conversion
    ↓
final Theme struct
```

The executable then contains only the finished theme values.

No runtime color generation is required for built-in themes.

---

# 23. Compile-time theme validation

Theme generation should support build-time invariants.

For example:

```d
static assert(validateTheme(lightTheme));
```

Validation may verify:

- minimum contrast ratios;
- final colors inside the target gamut;
- monotonic lightness of tone scales;
- valid alpha ranges;
- minimum perceptual separation between selected states;
- consistency of semantic palettes;
- finite color values.

A theme violating required invariants can therefore fail compilation instead of producing a defective runtime result.

---

# 24. `enum` versus `static immutable`

Manifest constants are appropriate for small generation parameters:

```d
enum seed = ...;
```

Generated themes and larger arrays should normally be stored as:

```d
static immutable
```

This gives:

- compile-time calculation;
- one concrete runtime representation;
- no repeated reconstruction of larger compound values.

---

# 25. Precomputed renderer representations

A built-in theme may optionally generate more than one final representation during CTFE.

Example:

```d
struct ThemeColor
{
    SRgba8 encoded;
    LinearSRgbf linear;
}
```

This permits:

```text
Theme seed
    ↓ compile time

SRgba8 representation
LinearSRgb representation
GPU-oriented tables
```

Runtime initialization can then reduce to simple table access or buffer upload.

Whether duplicate representations are desirable should be decided through profiling.

---

# 26. Runtime theme adaptation

CTFE does not replace runtime rendering adaptation.

Compile-time generation is appropriate for:

- built-in Light themes;
- Dark themes;
- High Contrast themes;
- semantic tone scales;
- fixed design tokens;
- precomputed map styles.

Runtime processing remains necessary for:

- user-selected arbitrary colors;
- theme editors;
- OS-selected appearance;
- animation between themes;
- image-dependent adaptive contrast;
- map-background luminance analysis;
- adaptive casing;
- dynamic imagery overlays;
- future HDR/display-specific processing.

---

# 27. OSM editor usage

`color-d` provides mathematical primitives for the editor but knows nothing about OSM tags.

Example higher-level structure:

```text
Editor Theme
│
├── GUI
│   ├── surfaces
│   ├── text
│   ├── controls
│   └── status
│
├── Map
│   ├── roads
│   ├── buildings
│   ├── water
│   ├── landcover
│   └── relations
│
└── Editing
    ├── selection
    ├── hover
    ├── snapping
    ├── topology
    └── validation
```

Semantic colors may be generated at compile time.

Actual rendering adaptation can then combine those semantic colors with runtime information about the map background.

---

# 28. Adaptive rendering

The editor may use semantic colors as stable identities while adapting visibility through:

- light/dark casing;
- dual casing;
- stroke width;
- alpha;
- patterns;
- local luminance information.

Conceptually:

```text
compile-time semantic style
            +
runtime background information
            ↓
adaptive rendered style
```

The color library provides:

- luminance;
- contrast;
- Oklab/OKLCH;
- gamut mapping;
- compositing.

The renderer decides actual styling.

---

# 29. GPU interoperability

Core color types should be simple POD-like structs with predictable component layout.

Example:

```d
struct Oklab(T)
{
    T l;
    T a;
    T b;
}
```

The library should avoid:

- heap pointers;
- hidden allocations;
- global state;
- graphics API dependencies.

However, `color-d` shall not promise that its native layout directly satisfies every GPU ABI such as:

- `std140`;
- `std430`;
- Vulkan-specific layouts;
- WebGPU alignment rules.

GPU-specific adapters belong in renderer code.

---

# 30. Performance model

`color-d` is not expected to perform complex conversions for millions of map primitives every frame.

Preferred architecture:

```text
color-d
    ↓
style/theme generation
    ↓
cached style tables
    ↓
renderer
    ↓
GPU
```

Frequently used colors should normally be precomputed.

Runtime conversion remains available for:

- user interaction;
- dynamic analysis;
- imagery-dependent adaptation;
- tooling.

The mathematical core itself should nevertheless remain efficient enough for normal hot-path use.

---

# 31. Allocation policy

Core color operations should normally allocate nothing.

Preferred properties:

```text
value types
stack-friendly
no GC
no hidden arrays
no global state
```

Public mathematical operations should strive for:

```d
@safe
pure
nothrow
@nogc
```

where semantically and technically appropriate.

---

# 32. Testing strategy

Tests must combine standards vectors, external references and algebraic properties.

Required classes:

## Reference values

Use known vectors for:

```text
sRGB transfer functions
XYZ conversion
Oklab
OKLCH
relative luminance
contrast
gamut mapping
```

## Round-trip tests

Examples:

```text
SRgb → LinearSRgb → SRgb
SRgb → XYZ → SRgb
SRgb → Oklab → SRgb
Oklab → OKLCH → Oklab
```

with scalar-specific tolerances.

## Edge cases

Test:

```text
black
white
RGB primaries
gamut boundaries
out-of-gamut values
alpha = 0
alpha = 1
negative RGB intermediates
components > 1
zero chroma
hue wrapping
NaN
infinity
```

## Property tests

Potential properties:

- identity round trips;
- monotonic tone-scale lightness;
- valid alpha composition bounds;
- gamut-mapped outputs lie inside target gamut;
- hue-path consistency;
- deterministic CTFE/runtime equality.

---

# 33. Numerical tolerances

The project shall not define one universal epsilon.

Tolerance depends on:

- scalar type;
- operation;
- transfer function;
- matrix multiplication;
- trigonometric conversion;
- gamut mapping.

Separate tolerances should be documented for:

```text
float
double
round-trip conversion
reference-vector comparison
boundary classification
```

---

# 34. CTFE/runtime equivalence testing

Core operations intended for CTFE should be tested in both modes.

Example concept:

```d
enum compileTime = someColor.toOklab;

auto runtime = someColor.toOklab;

assert(approxEqual(compileTime, runtime));
```

This guards against accidental divergence when implementations are optimized.

---

# 35. Preliminary module structure

The structure remains provisional.

```text
source/color/
    package.d

    rgb.d
    linear_rgb.d
    xyz.d

    oklab.d
    oklch.d

    hsl.d
    hsv.d

    alpha.d
    composite.d

    convert.d
    luminance.d
    contrast.d

    interpolate.d
    gamut.d

    difference.d
    palette.d
```

Possible later modules:

```text
source/color/cie/
    lab.d
    lch.d

source/color/widegamut/
    display_p3.d
    rec2020.d

source/color/picker/
    okhsl.d
    okhsv.d
```

Module boundaries should follow actual implementation dependencies rather than this draft mechanically.

---

# 36. External implementation references

Existing work should be treated as references rather than API templates.

Important references include:

- historical `TurkeyMan/color`;
- `AuburnSounds/colors`;
- `arsd.color`;
- Rust `palette`;
- Color.js;
- modern CSS Color specifications;
- Oklab reference implementation.

The historical `TurkeyMan/color` project is particularly valuable for:

- D-specific generic color types;
- whitepoint handling;
- transfer functions;
- allocation-free implementation techniques;
- `@safe pure nothrow @nogc` design.

However, `color-d` intentionally differs by emphasizing:

- explicit rather than cast-style conversions;
- distinct linear/nonlinear RGB types;
- Oklab/OKLCH as first-class modern spaces;
- explicit extended-range computation;
- orthogonal alpha typing;
- modern gamut semantics.

---

# 37. Initial v0.1 scope

Target functionality:

```text
SRgb8
SRgba8

SRgb!T
LinearSRgb!T
XyzD65!T

Oklab!T
Oklch!T

Hsl!T
Hsv!T

explicit conversions

Alpha!Color
premultiplied-alpha representation

linear-light source-over compositing

relative luminance
WCAG-style contrast ratio

same-space interpolation
HuePath handling

deltaEOK

inGamut
clip

explicit perceptual gamut mapping
with Local MINDE and Ray Trace as validated initial candidates

OKLCH tone-scale generation

CTFE support and tests
```

---

# 38. Deferred functionality

Later only with concrete consumers:

```text
Display-P3
Rec.2020
CIELAB / LCh
CIEDE2000
Okhsl
Okhsv
CSS parser / serializer
named colors
color-temperature models
scientific palettes
categorical palettes
color-vision-deficiency simulation
HDR
ICC
CMYK
GPU shader helpers
```

---

# 39. Dependency direction

Expected workspace relationships:

```text
color-d
   ↑
imagery-d

color-d
   ↑
theme/style layer
   ↑
OSM editor
```

`color-d` shall not depend on either `imagery-d` or `osm-d`.

---

# 40. Core design statement

The intended identity of the library is:

> **A small, type-safe, allocation-free, modern color mathematics library for D, centered on explicit color spaces, correct linear-light operations and perceptual color workflows.**

The most important properties are not the number of supported color spaces.

They are:

1. semantic type safety;
2. explicit color-space transitions;
3. preservation of mathematically valid out-of-gamut intermediates;
4. correct linear-light operations;
5. modern perceptual workflows through Oklab/OKLCH;
6. explicit alpha and gamut semantics;
7. runtime efficiency;
8. compile-time evaluability;
9. deterministic testability.

---

# 41. Implementation strategy

Before freezing a public v0.1 API, perform a focused architecture/prototype phase covering:

1. concrete D struct layouts;
2. `float`/`double` generic implementation;
3. explicit conversion API ergonomics;
4. alpha wrapper ergonomics;
5. premultiplied representation;
6. extended-sRGB range behavior;
7. Oklab/OKLCH conversions;
8. CTFE compatibility;
9. compile-time tone generation;
10. compile-time theme generation;
11. compile-time theme validation;
12. promotion of validated gamut semantics and initial mapping candidates;
13. comparison against standards/reference vectors;
14. basic performance and generated-code inspection.

No API should be considered stable until these questions have been exercised by at least one real consumer.

---

# 42. Working rule for future development

New functionality belongs in `color-d` only when at least one of the following applies:

- it is fundamental to correct color mathematics;
- an existing consumer requires it;
- standards interoperability clearly requires it;
- research shows it is necessary to preserve architectural consistency.

The project should avoid becoming a generic collection of every known color algorithm.

The goal is a small, coherent foundation that can remain stable and trustworthy.