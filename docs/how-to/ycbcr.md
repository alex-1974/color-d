# YCbCr conversion

`color.ycbcr` provides value-level YCbCr conversion without image, plane, or
codec dependencies. The caller must select an explicit matrix, range, and
optional bit-depth policy:

| Policy | Matrix | Input code interpretation |
| --- | --- | --- |
| `Bt601Full` | BT.601 | Y 0..1, neutral Cb/Cr 0.5 |
| `Bt601Video` | BT.601 | Y 16..235, Cb/Cr 16..240 in 8-bit notation |
| `Bt709Full` | BT.709 | Y 0..1, neutral Cb/Cr 0.5 |
| `Bt709Video` | BT.709 | Y 16..235, Cb/Cr 16..240 in 8-bit notation |
| `Bt2020Full` | BT.2020 | Y 0..1, neutral Cb/Cr 0.5 |
| `Bt2020Video` | BT.2020 | Y 16..235, Cb/Cr 16..240 in 8-bit notation |

Samples are normalized `float` or `double` values. Packed code values can be
decoded and quantized with `YCbCrCode!Policy`; policies support 8 through 16
bits.
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

## Convert encoded sRGB to YCbCr

The inverse scalar operation starts from encoded sRGB. It does not accept
linear-light sRGB because YCbCr matrix coefficients operate on nonlinear code
values:

```d
const rgb = SRgbd(0.2, 0.4, 0.8);
const ycbcr = rgb.toYCbCr!Bt709Video;
const roundTrip = ycbcr.toSRgb;
```

Linear-light sRGB is supported explicitly through the sRGB transfer boundary:

```d
const linearYcbcr = SRgbd(0.2, 0.4, 0.8).toLinear.toYCbCr!Bt709Video;
const linearAgain = linearYcbcr.toLinearSRgb;
```

Packed code values can be decoded with the same policy. This example uses a
10-bit full-range BT.2020 value:

```d
alias Bt2020Full10 = YCbCrPolicy!(YCbCrMatrix.bt2020,
    YCbCrRange.full, 10);
const packed = YCbCrCode!Bt2020Full10(512, 512, 512);
const normalized = packed.toYCbCr!double;
```

The result remains normalized and unquantized. `Bt709Video` places luma in the
normalized equivalents of codes 16..235 and chroma in 16..240. Byte rounding,
plane layout, chroma sampling, and codec metadata remain consumer/codec
responsibilities. The conversion is a total mathematical operation and does
not return an `error-d` `Result`; invalid or extended floating-point values
remain visible according to the scalar arithmetic contract.
