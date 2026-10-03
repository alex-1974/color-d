/++
 Compact encoded-sRGB storage values.

 `SRgb8` stores encoded sRGB red, green, and blue bytes. `SRgba8` adds a
 straight-alpha byte while keeping the RGB bytes independent of opacity.
 Both are deliberately distinct from the floating-point computational color
 types.

 Storage/computational conversion is explicit. Byte storage normalizes through
 division by 255; checked conversion back to storage rejects values outside
 inclusive [0, 1] and uses nearest-byte half-up quantization. It does not
 implicitly clip, gamut-map, or repair special values.

 Storage_Model:
     The packed layouts are:

     ---
     SRgb8
         r : ubyte
         g : ubyte
         b : ubyte

     SRgba8
         r : ubyte
         g : ubyte
         b : ubyte
         a : ubyte
     ---

     `SRgb8` is exactly three bytes in R/G/B order. `SRgba8` is exactly
     four bytes in R/G/B/A order. Both use byte alignment.

 Alpha_Model:
     `SRgba8.a` is straight alpha: 0 is fully transparent and 255 is fully
     opaque. RGB bytes are not premultiplied and remain independently stored,
     including when alpha is zero.

 Default_State:
     `SRgb8.init` is encoded sRGB black. `SRgba8.init` is transparent
     black.

 Allocation:
     Both storage types are plain values with no hidden allocation or ownership.

 Conversion:
     Storage to computation is total and normalized. Computation to storage is
     checked: out-of-range values, NaN, and infinities fail without modifying
     caller-owned output.

 Compile_Time:
     Aggregate construction and the public conversion operations are usable at
     CTFE.

 See_Also:
     color.rgb, color.alpha
+/
module color.storage;

private import color.alpha :
    Alpha;
private import color.rgb :
    SRgb,
    SRgbf,
    SRgbd;


/**
 * Packed 8-bit encoded-sRGB storage.
 *
 * Each component is an unsigned byte in encoded sRGB channel space. The type
 * is intended for compact tables, UI/configuration boundaries, renderer
 * interchange, and similar storage-facing uses.
 *
 * This is not a computational replacement for `SRgb!T`: it has no implicit
 * conversion to or from the floating-point color types, and construction does
 * not perform normalization, clipping, transfer conversion, or gamut mapping.
 *
 * Layout:
 *     Exactly three bytes in red, green, blue order:
 *     `r` at byte 0, `g` at byte 1, and `b` at byte 2.
 *
 * Default:
 *     `.init` is `SRgb8(0, 0, 0)`.
 */
struct SRgb8
{
    /// Storage channel type.
    alias Channel = ubyte;

    /// Red encoded-sRGB byte.
    Channel r;

    /// Green encoded-sRGB byte.
    Channel g;

    /// Blue encoded-sRGB byte.
    Channel b;

    /**
     * Converts packed encoded-sRGB bytes to normalized computational sRGB.
     *
     * Each byte is divided by 255 in the requested scalar type. No transfer
     * function, clipping, gamut mapping, or other color-space conversion
     * occurs.
     *
     * Returns:
     *     An `SRgb!T` value whose components are in inclusive `[0, 1]`.
     */
    SRgb!T toSRgb(T)() const
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        return SRgb!T(
            storageChannelToUnit!T(r),
            storageChannelToUnit!T(g),
            storageChannelToUnit!T(b)
        );
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        enum packed = SRgb8(255, 128, 0);
        enum normalized = packed.toSRgb!double();

        static assert(normalized.r == 1.0);
        static assert(normalized.g == 128.0 / 255.0);
        static assert(normalized.b == 0.0);
    }
}

///
@safe pure nothrow @nogc unittest
{
    enum accent = SRgb8(0x24, 0x7A, 0xC4);

    static assert(accent.r == 0x24);
    static assert(accent.g == 0x7A);
    static assert(accent.b == 0xC4);

    const copy = accent;
    assert(copy == accent);
}


static assert(is(SRgb8.Channel == ubyte));

static assert(SRgb8.sizeof == 3 * ubyte.sizeof);
static assert(SRgb8.alignof == ubyte.alignof);
static assert(SRgb8.r.offsetof == 0);
static assert(SRgb8.g.offsetof == 1);
static assert(SRgb8.b.offsetof == 2);

static assert(SRgb8.init.r == 0);
static assert(SRgb8.init.g == 0);
static assert(SRgb8.init.b == 0);

static assert(!__traits(compiles, SRgb8.init.toSRgb!int()));
static assert(!__traits(compiles, SRgb8.init.toSRgb!real()));


@safe pure nothrow @nogc unittest
{
    const black = SRgb8.init;
    const white = SRgb8(ubyte.max, ubyte.max, ubyte.max);

    assert(black == SRgb8(0, 0, 0));
    assert(white.r == 255);
    assert(white.g == 255);
    assert(white.b == 255);

    assert(black != white);
}


/**
 * Packed 8-bit encoded-sRGB storage with straight alpha.
 *
 * RGB components are unsigned encoded-sRGB bytes. `a` is straight opacity:
 * 0 is fully transparent and 255 is fully opaque. RGB bytes are never
 * premultiplied by alpha; hidden RGB remains stored even at zero alpha.
 *
 * This type does not implicitly convert to floating-point straight-alpha or
 * premultiplied computational representations. Construction performs no
 * normalization, clipping, transfer conversion, alpha conversion, or gamut
 * mapping.
 *
 * Layout:
 *     Exactly four bytes in red, green, blue, alpha order:
 *     `r` at byte 0, `g` at byte 1, `b` at byte 2, and `a` at byte 3.
 *
 * Default:
 *     `.init` is `SRgba8(0, 0, 0, 0)`, transparent black.
 */
struct SRgba8
{
    /// Storage channel type for RGB and alpha.
    alias Channel = ubyte;

    /// Red encoded-sRGB byte.
    Channel r;

    /// Green encoded-sRGB byte.
    Channel g;

    /// Blue encoded-sRGB byte.
    Channel b;

    /// Straight-alpha byte: 0 is transparent, 255 is opaque.
    Channel a;

    /**
     * Converts packed RGBA bytes to normalized straight-alpha encoded sRGB.
     *
     * RGB and alpha bytes are divided independently by 255 in the requested
     * scalar type. RGB remains straight and is not premultiplied by alpha,
     * including when alpha is zero.
     *
     * Returns:
     *     Straight `Alpha!(SRgb!T)` with every component in inclusive
     *     `[0, 1]`.
     */
    Alpha!(SRgb!T) toAlphaSRgb(T)() const
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        return Alpha!(SRgb!T)(
            SRgb!T(
                storageChannelToUnit!T(r),
                storageChannelToUnit!T(g),
                storageChannelToUnit!T(b)
            ),
            storageChannelToUnit!T(a)
        );
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        enum packed = SRgba8(255, 64, 0, 128);
        enum normalized = packed.toAlphaSRgb!double();

        static assert(normalized.color.r == 1.0);
        static assert(normalized.color.g == 64.0 / 255.0);
        static assert(normalized.color.b == 0.0);
        static assert(normalized.alpha == 128.0 / 255.0);
    }
}

///
@safe pure nothrow @nogc unittest
{
    enum translucentAccent = SRgba8(0x24, 0x7A, 0xC4, 0x80);

    static assert(translucentAccent.r == 0x24);
    static assert(translucentAccent.g == 0x7A);
    static assert(translucentAccent.b == 0xC4);
    static assert(translucentAccent.a == 0x80);

    // Straight alpha keeps RGB independent from opacity.
    enum transparentAccent = SRgba8(0x24, 0x7A, 0xC4, 0);
    static assert(transparentAccent.r == 0x24);
    static assert(transparentAccent.g == 0x7A);
    static assert(transparentAccent.b == 0xC4);
}


static assert(is(SRgba8.Channel == ubyte));

static assert(SRgba8.sizeof == 4 * ubyte.sizeof);
static assert(SRgba8.alignof == ubyte.alignof);
static assert(SRgba8.r.offsetof == 0);
static assert(SRgba8.g.offsetof == 1);
static assert(SRgba8.b.offsetof == 2);
static assert(SRgba8.a.offsetof == 3);

static assert(SRgba8.init.r == 0);
static assert(SRgba8.init.g == 0);
static assert(SRgba8.init.b == 0);
static assert(SRgba8.init.a == 0);

static assert(!__traits(compiles, SRgba8.init.toAlphaSRgb!int()));
static assert(!__traits(compiles, SRgba8.init.toAlphaSRgb!real()));


@safe pure nothrow @nogc unittest
{
    const transparentBlack = SRgba8.init;
    const opaqueWhite = SRgba8(
        ubyte.max,
        ubyte.max,
        ubyte.max,
        ubyte.max
    );

    assert(transparentBlack == SRgba8(0, 0, 0, 0));
    assert(opaqueWhite == SRgba8(255, 255, 255, 255));
    assert(transparentBlack != opaqueWhite);

    // Zero alpha does not canonicalize or erase hidden straight RGB.
    const hiddenRed = SRgba8(255, 0, 0, 0);
    assert(hiddenRed.r == 255);
    assert(hiddenRed.a == 0);
}


private T storageChannelToUnit(T)(
    ubyte value
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        cast(T)value /
        cast(T)ubyte.max;
}


private bool isStorableUnit(T)(
    T value
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        value >= cast(T)0 &&
        value <= cast(T)1;
}


private ubyte unitToStorageChannel(T)(
    T value
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T scaled =
        value * cast(T)ubyte.max +
        cast(T)0.5;

    return cast(ubyte)cast(uint)scaled;
}


/**
 * Tries to quantize normalized encoded sRGB into `SRgb8`.
 *
 * All three source components must be finite values in inclusive `[0, 1]`.
 * Values outside that domain, NaN, and infinities are rejected. No clipping
 * or gamut mapping occurs.
 *
 * Quantization rounds to the nearest byte; exact half steps choose the larger
 * byte. The endpoints map exactly: 0 maps to 0 and 1 maps to 255.
 *
 * Params:
 *     value = Normalized computational encoded-sRGB value.
 *     output = Destination storage value. It is unchanged on failure.
 *
 * Returns:
 *     `true` when all components were stored; otherwise `false`.
 */
bool tryToSRgb8(T)(
    SRgb!T value,
    ref SRgb8 output
)
@safe pure nothrow @nogc
{
    if (
        !isStorableUnit(value.r) ||
        !isStorableUnit(value.g) ||
        !isStorableUnit(value.b)
    )
    {
        return false;
    }

    const candidate =
        SRgb8(
            unitToStorageChannel(value.r),
            unitToStorageChannel(value.g),
            unitToStorageChannel(value.b)
        );

    output = candidate;
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    SRgb8 packed = SRgb8(1, 2, 3);

    assert(tryToSRgb8(
        SRgbd(1.0, 0.5, 0.0),
        packed
    ));
    assert(packed == SRgb8(255, 128, 0));

    const beforeFailure = packed;

    assert(!tryToSRgb8(
        SRgbd(double.nan, 0.5, 0.0),
        packed
    ));
    assert(packed == beforeFailure);
}


/**
 * Tries to quantize normalized straight-alpha encoded sRGB into `SRgba8`.
 *
 * RGB and alpha must all be finite values in inclusive `[0, 1]`. Failure
 * does not clip, premultiply, repair special values, or modify the destination.
 * RGB is quantized independently from straight alpha.
 *
 * Quantization rounds to the nearest byte; exact half steps choose the larger
 * byte.
 *
 * Params:
 *     value = Normalized straight-alpha encoded-sRGB computational value.
 *     output = Destination storage value. It is unchanged on failure.
 *
 * Returns:
 *     `true` when RGB and alpha were stored; otherwise `false`.
 */
bool tryToSRgba8(T)(
    Alpha!(SRgb!T) value,
    ref SRgba8 output
)
@safe pure nothrow @nogc
{
    if (
        !isStorableUnit(value.color.r) ||
        !isStorableUnit(value.color.g) ||
        !isStorableUnit(value.color.b) ||
        !isStorableUnit(value.alpha)
    )
    {
        return false;
    }

    const candidate =
        SRgba8(
            unitToStorageChannel(value.color.r),
            unitToStorageChannel(value.color.g),
            unitToStorageChannel(value.color.b),
            unitToStorageChannel(value.alpha)
        );

    output = candidate;
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    SRgba8 packed = SRgba8(1, 2, 3, 4);

    assert(tryToSRgba8(
        Alpha!SRgbd(
            SRgbd(1.0, 0.5, 0.0),
            0.5
        ),
        packed
    ));
    assert(packed == SRgba8(255, 128, 0, 128));

    const beforeFailure = packed;

    assert(!tryToSRgba8(
        Alpha!SRgbd(
            SRgbd(0.25, 0.5, 0.75),
            double.infinity
        ),
        packed
    ));
    assert(packed == beforeFailure);
}


private bool allStorageRoundTrips(T)()
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    foreach (i; 0u .. 256u)
    {
        const byteValue = cast(ubyte)i;

        const rgb =
            SRgb8(
                byteValue,
                byteValue,
                byteValue
            );

        SRgb8 rgbRoundTrip =
            SRgb8(11, 22, 33);

        if (!tryToSRgb8(
            rgb.toSRgb!T(),
            rgbRoundTrip
        ))
        {
            return false;
        }

        if (rgbRoundTrip != rgb)
            return false;

        const rgba =
            SRgba8(
                byteValue,
                byteValue,
                byteValue,
                byteValue
            );

        SRgba8 rgbaRoundTrip =
            SRgba8(11, 22, 33, 44);

        if (!tryToSRgba8(
            rgba.toAlphaSRgb!T(),
            rgbaRoundTrip
        ))
        {
            return false;
        }

        if (rgbaRoundTrip != rgba)
            return false;
    }

    return true;
}


static assert(allStorageRoundTrips!float());
static assert(allStorageRoundTrips!double());


@safe pure nothrow @nogc unittest
{
    // Half-up quantization for an exactly representable midpoint.
    SRgb8 half = SRgb8.init;
    assert(tryToSRgb8(
        SRgbf(0.5f, 0.5f, 0.5f),
        half
    ));
    assert(half == SRgb8(128, 128, 128));

    // Signed zero is a valid endpoint.
    SRgb8 zero = SRgb8(9, 9, 9);
    assert(tryToSRgb8(
        SRgbd(-0.0, 0.0, 0.0),
        zero
    ));
    assert(zero == SRgb8(0, 0, 0));

    // Every invalid class rejects without changing caller-owned storage.
    const invalidInputs =
    [
        SRgbd(-0.001, 0.0, 0.0),
        SRgbd(1.001, 0.0, 0.0),
        SRgbd(double.nan, 0.0, 0.0),
        SRgbd(double.infinity, 0.0, 0.0),
        SRgbd(-double.infinity, 0.0, 0.0)
    ];

    foreach (value; invalidInputs)
    {
        SRgb8 destination =
            SRgb8(7, 8, 9);

        assert(!tryToSRgb8(
            value,
            destination
        ));
        assert(destination == SRgb8(7, 8, 9));
    }

    SRgba8 rgbaDestination =
        SRgba8(4, 5, 6, 7);

    assert(!tryToSRgba8(
        Alpha!SRgbd(
            SRgbd(-0.01, 0.5, 0.75),
            0.5
        ),
        rgbaDestination
    ));
    assert(rgbaDestination == SRgba8(4, 5, 6, 7));

    assert(!tryToSRgba8(
        Alpha!SRgbd(
            SRgbd(0.25, 0.5, 0.75),
            double.nan
        ),
        rgbaDestination
    ));
    assert(rgbaDestination == SRgba8(4, 5, 6, 7));
}


version (unittest)
{
    private void acceptStorage(SRgb8)
    @safe pure nothrow @nogc
    {
    }

    private void acceptComputational(SRgbf)
    @safe pure nothrow @nogc
    {
    }

    static assert(!__traits(
        compiles,
        acceptComputational(SRgb8.init)
    ));

    static assert(!__traits(
        compiles,
        acceptStorage(SRgbf.init)
    ));

    private void acceptStorageAlpha(SRgba8)
    @safe pure nothrow @nogc
    {
    }

    private void acceptComputationalAlpha(Alpha!SRgbf)
    @safe pure nothrow @nogc
    {
    }

    static assert(!__traits(
        compiles,
        acceptComputationalAlpha(SRgba8.init)
    ));

    static assert(!__traits(
        compiles,
        acceptStorageAlpha(Alpha!SRgbf.init)
    ));
}
