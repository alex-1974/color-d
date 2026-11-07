# YCbCr conversion

`color.ycbcr` provides value-level YCbCr conversion without image, plane, or
codec dependencies. The caller must select one of the four explicit policies:

| Policy | Matrix | Input code interpretation |
| --- | --- | --- |
| `Bt601Full` | BT.601 | Y 0..1, neutral Cb/Cr 0.5 |
| `Bt601Video` | BT.601 | Y 16..235, Cb/Cr 16..240 in 8-bit notation |
| `Bt709Full` | BT.709 | Y 0..1, neutral Cb/Cr 0.5 |
| `Bt709Video` | BT.709 | Y 16..235, Cb/Cr 16..240 in 8-bit notation |

Samples are normalized `float` or `double` values. Integer samples are not
accepted because the caller owns bit-depth and storage-range interpretation.
For video range, `Y=16/255` maps to black, `Y=235/255` maps to white, and
`Cb=Cr=128/255` is neutral. Values outside the legal range remain extended.

```d
import color;

alias Policy = Bt601Video;
const ycbcr = YCbCr!(double, Policy)(16.0 / 255.0,
    128.0 / 255.0, 128.0 / 255.0);

const encoded = ycbcr.toSRgb;         // encoded sRGB
const linear = ycbcr.toLinearSRgb;    // linear-light sRGB
const clipped = ycbcr.toSRgbClamped;  // explicit [0, 1] clipping
```

`toSRgb` does not clip, round, or quantize. `toSRgbClamped` clips finite
components explicitly; NaN and infinity remain non-finite. There is no implicit
policy selection, chroma upsampling, plane interpretation, or image ownership.
