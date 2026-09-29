# Alpha and compositing

`color-d` keeps straight alpha and premultiplied alpha as different types.

## Straight alpha

```d
import color;

const straight = Alpha!LinearSRgbd(
    LinearSRgbd(0.8, 0.2, 0.1),
    0.5
);

assert(straight.isValidAlpha);
```

Construction stores values as supplied. Alpha is not silently clamped.

## Premultiply explicitly

```d
const premultiplied = straight.premultiply;
const restored = premultiplied.unpremultiply;
```

Premultiplied public values are restricted to linear-light sRGB. At alpha zero,
premultiplication loses hidden straight RGB; unpremultiplication therefore
returns the library's deterministic zero-alpha representation rather than
inventing hidden color.

## Source-over compositing

Source-over operates on premultiplied linear-light values:

```d
const result = sourceOver(sourcePremultiplied, destinationPremultiplied);
```

Encoded sRGB is not accepted as if it were linear-light compositing data.
Image-level masks, NoData, channel binding, and layer orchestration remain
consumer responsibilities. They are not alpha channels and color-d does not
merge those concepts.
