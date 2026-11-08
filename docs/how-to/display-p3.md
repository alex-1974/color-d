# Display-P3

`color.p3` provides encoded and linear Display-P3 values using the sRGB
transfer curve. Conversion to sRGB goes through XYZ D65 and never clips or
gamut-maps implicitly.

```d
import color;

const p3 = DisplayP3d(0.2, 0.4, 0.8);
const linear = p3.toLinear;
const xyz = linear.toXyzD65;
const srgb = p3.toSRgb;
const restored = srgb.toDisplayP3;
```

Use an explicit gamut policy when a Display-P3 value must be presented on an
sRGB-only target.
