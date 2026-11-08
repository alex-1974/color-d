# HSL and HSV

`color.hsl` provides value-based HSL and HSV conversions for encoded sRGB.
Hue is represented as turns (`0..1`), and achromatic colors use hue `0`.

```d
import color;

const rgb = SRgbd(0.2, 0.4, 0.8);
const hsl = rgb.toHsl;
const hsv = rgb.toHsv;
const restoredFromHsl = hsl.toSRgb;
const restoredFromHsv = hsv.toSRgb;
```

These conversions preserve the value-oriented, allocation-free model. They do
not clamp extended components or apply gamut mapping.
