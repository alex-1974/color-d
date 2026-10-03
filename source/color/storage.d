/++
 Compact encoded-sRGB storage values.

 `SRgb8` is a storage/interchange representation with one unsigned 8-bit
 channel for red, green, and blue. It is deliberately distinct from the
 floating-point computational `SRgb!T` type.

 This module does not define normalization, quantization, clipping, or
 floating-point conversion policy. Those operations require an explicit
 storage/conversion contract and are provided separately.

 Storage_Model:
     `SRgb8` stores encoded, nonlinear sRGB channel bytes directly:

     ---
     SRgb8
         r : ubyte
         g : ubyte
         b : ubyte
     ---

     The layout is exactly three bytes in R/G/B order with byte alignment.

 Default_State:
     The natural D `.init` value is `SRgb8(0, 0, 0)`, representing encoded
     sRGB black.

 Allocation:
     `SRgb8` is a plain value type with no hidden allocation or ownership.

 Compile_Time:
     Aggregate construction and ordinary value operations are usable at CTFE.

 See_Also:
     color.rgb
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


version (unittest)
{
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
}
