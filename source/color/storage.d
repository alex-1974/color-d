/++
 Compact encoded-sRGB storage values.

 `SRgb8` stores encoded sRGB red, green, and blue bytes. `SRgba8` adds a
 straight-alpha byte while keeping the RGB bytes independent of opacity.
 Both are deliberately distinct from the floating-point computational color
 types.

 This module does not define normalization, quantization, clipping, or
 floating-point conversion policy. Those operations require an explicit
 storage/conversion contract and are provided separately.

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

 Compile_Time:
     Aggregate construction and ordinary value operations are usable at CTFE.

 See_Also:
     color.rgb, color.alpha
+/
module color.storage;


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


version (unittest)
{
    private import color.alpha : Alpha;
    private import color.rgb : SRgbf;

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
