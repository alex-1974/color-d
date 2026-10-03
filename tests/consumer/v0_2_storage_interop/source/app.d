module app;

import color;


/++
    Consumer-owned editor token. The semantic role and validity state belong
    to the application; color-d supplies only storage and color mathematics.
+/
struct EditorToken
{
    bool valid;
    SRgba8 storage;
    Alpha!SRgbf encoded;
    LinearSRgbf linear;
    float alpha;
    char[9] canonicalHex;
}


/++
    Parses one exact full-byte RGBA configuration value and prepares the
    computational forms an editor/renderer may retain.

    Failure leaves the caller-owned destination unchanged.
+/
bool tryLoadEditorToken(
    scope const(char)[] text,
    ref EditorToken output
)
@safe pure nothrow @nogc
{
    SRgba8 storage =
        SRgba8.init;

    if (!tryParseSRgba8Hex(
        text,
        storage
    ))
    {
        return false;
    }

    const encoded =
        storage.toAlphaSRgb!float();

    const linear =
        encoded.color.toLinear;

    const candidate =
        EditorToken(
            true,
            storage,
            encoded,
            linear,
            encoded.alpha,
            storage.toHex()
        );

    output = candidate;
    return true;
}


/++
    Consumer-side imagery/render interchange value.

    This deliberately remains an application type rather than becoming a
    color-d semantic wrapper.
+/
struct RgbaPixel
{
    ubyte r;
    ubyte g;
    ubyte b;
    ubyte a;
}


Alpha!SRgbf importPixel(
    RgbaPixel pixel
)
@safe pure nothrow @nogc
{
    return
        SRgba8(
            pixel.r,
            pixel.g,
            pixel.b,
            pixel.a
        )
        .toAlphaSRgb!float();
}


bool tryExportPixel(
    Alpha!SRgbf value,
    ref RgbaPixel output
)
@safe pure nothrow @nogc
{
    SRgba8 storage =
        SRgba8.init;

    if (!tryToSRgba8(
        value,
        storage
    ))
    {
        return false;
    }

    output =
        RgbaPixel(
            storage.r,
            storage.g,
            storage.b,
            storage.a
        );

    return true;
}


private EditorToken requiredEditorToken(
    scope const(char)[] text
)
@safe pure nothrow @nogc
{
    EditorToken result;

    assert(
        tryLoadEditorToken(
            text,
            result
        )
    );

    return result;
}


/*
 * Built-in editor colors exercise the public storage/configuration boundary at
 * CTFE through the same root-import API used at runtime.
 */
enum builtInSelection =
    requiredEditorToken(
        "#247AC480"
    );

static assert(
    builtInSelection.valid
);

static assert(
    builtInSelection.storage ==
        SRgba8(
            0x24,
            0x7A,
            0xC4,
            0x80
        )
);

static assert(
    builtInSelection.canonicalHex[0] == '#'
    && builtInSelection.canonicalHex[1] == '2'
    && builtInSelection.canonicalHex[2] == '4'
    && builtInSelection.canonicalHex[3] == '7'
    && builtInSelection.canonicalHex[4] == 'a'
    && builtInSelection.canonicalHex[5] == 'c'
    && builtInSelection.canonicalHex[6] == '4'
    && builtInSelection.canonicalHex[7] == '8'
    && builtInSelection.canonicalHex[8] == '0'
);

static assert(
    builtInSelection.encoded.alpha ==
        128.0f / 255.0f
);

static assert(
    builtInSelection.linear.inGamut
);


/*
 * The consumer helpers themselves retain the desired hot-path attributes.
 * If any public operation allocates or throws, these declarations stop
 * compiling.
 */
static assert(
    __traits(compiles,
    {
        EditorToken token;

        bool ok =
            tryLoadEditorToken(
                "#247ac480",
                token
            );

        RgbaPixel pixel =
            RgbaPixel(
                0x24,
                0x7A,
                0xC4,
                0x80
            );

        auto encoded =
            importPixel(pixel);

        bool stored =
            tryExportPixel(
                encoded,
                pixel
            );

        assert(ok || !ok);
        assert(stored || !stored);
    })
);


void main()
{
    /*
     * Editor/configuration path:
     * full-byte hexadecimal -> packed storage -> computational encoded sRGB ->
     * explicit linear-light conversion.
     */
    EditorToken runtimeToken;

    assert(
        tryLoadEditorToken(
            "#247AC480",
            runtimeToken
        )
    );

    assert(runtimeToken.valid);
    assert(
        runtimeToken.storage ==
            builtInSelection.storage
    );

    assert(
        runtimeToken.canonicalHex[] ==
            "#247ac480"
    );

    assert(runtimeToken.linear.inGamut);


    /*
     * Parsing remains narrow and policy-neutral. A rejected shorthand value
     * must not overwrite the caller's existing token.
     */
    const beforeFailure =
        runtimeToken;

    assert(
        !tryLoadEditorToken(
            "#24c8",
            runtimeToken
        )
    );

    assert(
        runtimeToken ==
            beforeFailure
    );


    /*
     * Imagery/renderer boundary:
     * raw RGBA bytes -> color-d storage -> computational value -> checked
     * storage export. Every byte survives exactly.
     */
    const RgbaPixel sourcePixel =
        RgbaPixel(
            0x11,
            0x80,
            0xFE,
            0x40
        );

    const encodedPixel =
        importPixel(
            sourcePixel
        );

    RgbaPixel exportedPixel;

    assert(
        tryExportPixel(
            encodedPixel,
            exportedPixel
        )
    );

    assert(
        exportedPixel ==
            sourcePixel
    );


    /*
     * Straight alpha preserves hidden RGB at zero opacity; the application may
     * need it for editing even when nothing is visible.
     */
    const hiddenPixel =
        RgbaPixel(
            0xE0,
            0x20,
            0x60,
            0x00
        );

    const hiddenEncoded =
        importPixel(
            hiddenPixel
        );

    assert(hiddenEncoded.alpha == 0.0f);
    assert(hiddenEncoded.color.r > 0.0f);

    RgbaPixel hiddenRoundTrip;

    assert(
        tryExportPixel(
            hiddenEncoded,
            hiddenRoundTrip
        )
    );

    assert(
        hiddenRoundTrip ==
            hiddenPixel
    );


    /*
     * Bounded storage conversion is explicitly checked. The consumer decides
     * whether to clip/map before retrying; color-d does not import that policy.
     */
    RgbaPixel preserved =
        RgbaPixel(
            1,
            2,
            3,
            4
        );

    assert(
        !tryExportPixel(
            Alpha!SRgbf(
                SRgbf(
                    1.2f,
                    0.5f,
                    0.25f
                ),
                1.0f
            ),
            preserved
        )
    );

    assert(
        preserved ==
            RgbaPixel(
                1,
                2,
                3,
                4
            )
    );
}
