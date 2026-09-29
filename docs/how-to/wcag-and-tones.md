# WCAG measurements and tone families

## Measure WCAG 2 luminance

WCAG operations validate their standards-facing sRGB domain instead of
silently clipping invalid input.

```d
import color;

const black = wcag2RelativeLuminance(SRgbd(0, 0, 0));
const white = wcag2RelativeLuminance(SRgbd(1, 1, 1));

assert(black.valid);
assert(white.valid);
assert(black.value == 0);
assert(white.value == 1);
```

Invalid input produces an invalid `Wcag2Measurement`; inspect `.valid`
rather than treating the stored NaN as a success signal.

## Measure contrast, then apply application policy

```d
const ratio =
    wcag2ContrastRatio(
        SRgbd(0, 0, 0),
        SRgbd(1, 1, 1)
    );

assert(ratio.valid);
assert(ratio.value == 21);
```

`color-d` returns the standards-specific measurement. It does not decide
which AA/AAA threshold applies to a UI role or text context.

## Build a fixed tone schedule

```d
enum lightness = linearSchedule!5(0.20, 0.80);
```

The endpoints must be finite. This is a programmer precondition.

For caller-owned tone storage:

```d
const seed = Oklchd(
    0.50,
    0.10,
    OklabHued.fromDegrees(210.0)
);

const double[3] ls = [0.20, 0.50, 0.80];
const double[3] cs = [0.04, 0.10, 0.06];
Oklchd[3] tones;

tonesAtLightnessAndChromaInto(seed, ls, cs, tones);
```

For runtime-sized slices use `tryTonesAtLightnessAndChromaInto`. On length
mismatch it returns `false` and performs no output writes.

Semantic roles such as accent, warning, selected, or road classes remain in
the consumer theme/style layer.
