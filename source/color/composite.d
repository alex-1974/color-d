module color.composite;

private import color.alpha : Premultiplied;
private import color.rgb : LinearSRgb;

/**
 * Compose a premultiplied linear-light source over a destination.
 *
 * Both operands are premultiplied linear-light sRGB values. The first argument
 * is the source and the second is the destination.
 *
 * Porter-Duff source-over is evaluated as:
 *
 * $(PRE
 * out.rgb   = source.rgb +
 *             destination.rgb * (1 - source.alpha)
 *
 * out.alpha = source.alpha +
 *             destination.alpha * (1 - source.alpha)
 * )
 *
 * The operation performs only this arithmetic. It does not validate or clamp
 * alpha, clip RGB, perform gamut mapping, convert color spaces, or infer a
 * background. Extended-range linear RGB therefore remains representable.
 */
Premultiplied!(LinearSRgb!T) sourceOver(T)(
    Premultiplied!(LinearSRgb!T) source,
    Premultiplied!(LinearSRgb!T) destination
)
@safe pure nothrow @nogc
{
    const T destinationFactor =
        cast(T)1 - source.alpha;

    return Premultiplied!(LinearSRgb!T)(
        LinearSRgb!T(
            source.color.r +
                destination.color.r * destinationFactor,

            source.color.g +
                destination.color.g * destinationFactor,

            source.color.b +
                destination.color.b * destinationFactor
        ),

        source.alpha +
            destination.alpha * destinationFactor
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.alpha : Alpha, premultiply;
    import color.rgb : LinearSRgbf;

    const source = premultiply(
        Alpha!LinearSRgbf(
            LinearSRgbf(0.0f, 0.0f, 1.0f),
            0.5f
        )
    );

    const destination = premultiply(
        Alpha!LinearSRgbf(
            LinearSRgbf(1.0f, 0.0f, 0.0f),
            1.0f
        )
    );

    const result = sourceOver(source, destination);

    assert(result.color == LinearSRgbf(0.5f, 0.0f, 0.5f));
    assert(result.alpha == 1.0f);
}

version (unittest)
{
    private import color.alpha :
        Alpha,
        premultiply;

    private import color.rgb :
        SRgbf,
        LinearSRgbf,
        LinearSRgbd;

    private bool approxEqual(T)(
        T a,
        T b,
        T tolerance
    )
    @safe pure nothrow @nogc
    {
        const T difference = a - b;

        return (
            difference < cast(T)0
                ? -difference
                : difference
        ) <= tolerance;
    }

    private bool approxPremultiplied(T)(
        Premultiplied!(LinearSRgb!T) a,
        Premultiplied!(LinearSRgb!T) b,
        T tolerance
    )
    @safe pure nothrow @nogc
    {
        return
            approxEqual(a.color.r, b.color.r, tolerance) &&
            approxEqual(a.color.g, b.color.g, tolerance) &&
            approxEqual(a.color.b, b.color.b, tolerance) &&
            approxEqual(a.alpha, b.alpha, tolerance);
    }

    // Straight alpha is not accepted by the low-level compositor.
    static assert(!__traits(compiles,
        sourceOver(
            Alpha!LinearSRgbf(
                LinearSRgbf(0, 0, 0),
                1
            ),
            Alpha!LinearSRgbf(
                LinearSRgbf(0, 0, 0),
                1
            )
        )
    ));

    // Encoded straight sRGB is not accepted by the low-level compositor.
    static assert(!__traits(compiles,
        sourceOver(
            Alpha!SRgbf(
                SRgbf(0, 0, 0),
                1
            ),
            Alpha!SRgbf(
                SRgbf(0, 0, 0),
                1
            )
        )
    ));

    // Both operands must use the same scalar type.
    static assert(!__traits(compiles,
        sourceOver(
            Premultiplied!LinearSRgbf(
                LinearSRgbf(0, 0, 0),
                1
            ),
            Premultiplied!LinearSRgbd(
                LinearSRgbd(0, 0, 0),
                1
            )
        )
    ));

    // Canonical transparent source is the identity.
    enum referenceDestination = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0.3, 0.4, 0.5),
            0.7
        )
    );

    enum transparentSource = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0
        )
    );

    static assert(
        sourceOver(
            transparentSource,
            referenceDestination
        ) == referenceDestination
    );

    // Opaque source replaces the destination exactly.
    enum opaqueSource = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0.8, 0.1, 0.2),
            1
        )
    );

    static assert(
        sourceOver(
            opaqueSource,
            referenceDestination
        ) == opaqueSource
    );

    // Canonical transparent destination is the identity backdrop.
    enum transparentDestination =
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0, 0, 0),
            0
        );

    static assert(
        sourceOver(
            referenceDestination,
            transparentDestination
        ) == referenceDestination
    );

    // Half-transparent blue over opaque red.
    enum halfBlue = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 1),
            0.5
        )
    );

    enum opaqueRed = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            1
        )
    );

    enum blueOverOpaqueRed =
        sourceOver(halfBlue, opaqueRed);

    static assert(
        blueOverOpaqueRed ==
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0.5, 0, 0.5),
            1
        )
    );

    // Half-transparent blue over half-transparent red.
    enum halfRed = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.5
        )
    );

    enum blueOverHalfRed =
        sourceOver(halfBlue, halfRed);

    static assert(
        blueOverHalfRed ==
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0.25, 0, 0.5),
            0.75
        )
    );

    // Source-over is ordered and generally not commutative.
    enum redOverHalfBlue =
        sourceOver(halfRed, halfBlue);

    static assert(
        redOverHalfBlue ==
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0.5, 0, 0.25),
            0.75
        )
    );

    static assert(redOverHalfBlue != blueOverHalfRed);
    static assert(blueOverHalfRed.isValidAlpha);

    // Extended-range linear RGB is preserved rather than clipped.
    enum extendedSource = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(-0.2, 1.3, 0.5),
            0.25
        )
    );

    enum extendedDestination = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(1.2, -0.1, 0.3),
            0.5
        )
    );

    enum extendedResult =
        sourceOver(
            extendedSource,
            extendedDestination
        );

    static assert(approxPremultiplied(
        extendedResult,
        Premultiplied!LinearSRgbd(
            LinearSRgbd(
                0.4,
                0.2875,
                0.2375
            ),
            0.625
        ),
        1e-15
    ));

    static assert(extendedResult.isValidAlpha);

    // Raw invalid alpha is not silently clamped or repaired.
    enum invalidSource =
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0.75, 0, 0),
            1.5
        );

    enum invalidDestination =
        Premultiplied!LinearSRgbd(
            LinearSRgbd(0.25, 0, 0),
            0.5
        );

    enum invalidResult =
        sourceOver(
            invalidSource,
            invalidDestination
        );

    static assert(
        invalidResult.color ==
        LinearSRgbd(0.625, 0, 0)
    );
    static assert(invalidResult.alpha == 1.25);
    static assert(!invalidResult.isValidAlpha);

    // Porter-Duff source-over is associative under exact arithmetic.
    // Floating-point evaluation is compared with an explicit tolerance.
    enum layerA = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0.9, 0.2, 1.1),
            0.3
        )
    );

    enum layerB = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(-0.1, 0.8, 0.4),
            0.6
        )
    );

    enum layerC = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0.3, 0.7, 0.2),
            0.4
        )
    );

    enum associativeLeft =
        sourceOver(
            sourceOver(layerA, layerB),
            layerC
        );

    enum associativeRight =
        sourceOver(
            layerA,
            sourceOver(layerB, layerC)
        );

    static assert(approxPremultiplied(
        associativeLeft,
        associativeRight,
        1e-14
    ));

    // Exercise the float path during CTFE as well.
    enum halfBlueF = premultiply(
        Alpha!LinearSRgbf(
            LinearSRgbf(0, 0, 1),
            0.5f
        )
    );

    enum halfRedF = premultiply(
        Alpha!LinearSRgbf(
            LinearSRgbf(1, 0, 0),
            0.5f
        )
    );

    enum compositeF =
        sourceOver(halfBlueF, halfRedF);

    static assert(approxPremultiplied(
        compositeF,
        Premultiplied!LinearSRgbf(
            LinearSRgbf(0.25f, 0, 0.5f),
            0.75f
        ),
        3e-6f
    ));
}
