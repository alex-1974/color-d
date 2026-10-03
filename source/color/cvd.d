/++
 Model-specific color-vision-deficiency transformations in linear-light sRGB.

 The transformations in this module are mathematical display-simulation
 primitives. They do not classify accessibility, choose consumer thresholds,
 clip or gamut-map their results, or alter alpha.

 Brettel 1997 is exposed for protan, deutan, and tritan dichromacy. Viénot
 1999 is exposed only for protan and deutan, matching the validated display
 model boundary. Machado 2009 is exposed for protan and deutan with its own
 0..1 severity semantics; the published tritan table is deliberately not
 promoted because the research evidence does not support presenting it as an
 equally validated tritan model.

 All transforms operate on `LinearSRgb!T`. Callers starting from encoded sRGB
 must decode explicitly with `toLinear`, and may encode explicitly with
 `toSRgb` afterwards.

 The scalar callables are convenient for isolated colors. Repeated work can
 prepare the selected model once and then reuse the resulting value through
 `apply`, fixed-cardinality `applyInto`, or runtime-sized `tryApplyInto`
 without allocation.
+/
module color.cvd;

private import color.rgb :
    LinearSRgb,
    LinearSRgbd;


/**
 * Cone-deficiency families supported by the Brettel 1997 dichromat model.
 */
enum CvdDeficiency
{
    /// Protan-type deficiency.
    protan,

    /// Deutan-type deficiency.
    deutan,

    /// Tritan-type deficiency.
    tritan
}

///
@safe pure nothrow @nogc unittest
{
    const simulated =
        LinearSRgbd(0.2, 0.4, 0.7)
        .brettel1997Dichromat(
            CvdDeficiency.protan
        );

    assert(simulated.r == simulated.r);
}


/**
 * Red/green cone-deficiency families supported by the promoted Viénot 1999
 * and Machado 2009 operations.
 *
 * Tritan is intentionally absent. Viénot 1999 is not promoted for tritan, and
 * the Machado tritan table remains outside the production API because the
 * research evidence records a material model limitation for that case.
 */
enum RedGreenCvdDeficiency
{
    /// Protan-type deficiency.
    protan,

    /// Deutan-type deficiency.
    deutan
}

///
@safe pure nothrow @nogc unittest
{
    const simulated =
        LinearSRgbd(0.2, 0.4, 0.7)
        .vienot1999Dichromat(
            RedGreenCvdDeficiency.deutan
        );

    assert(simulated.g == simulated.g);
}


private struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
}


/*
 * R7.4.6 exact-production evidence shows opposite optimal value flow:
 *
 * - LDC/LLVM scalar-replaces a local prepared-state snapshot and keeps matrix
 *   coefficients loop-invariant/in registers;
 * - DMD preserves the original member-backed form more robustly and the local
 *   snapshot reintroduces material code-placement sensitivity.
 *
 * Keep this capability decision centralized and semantic-neutral. Re-evaluate
 * when the supported compiler/backend matrix changes materially.
 */
version (LDC)
{
    private enum bool usePreparedLocalSnapshot = true;
}
else
{
    private enum bool usePreparedLocalSnapshot = false;
}


private LinearSRgb!T applyMatrix(T)(
    const Matrix3!T matrix,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        matrix.m00 * color.r +
        matrix.m01 * color.g +
        matrix.m02 * color.b,

        matrix.m10 * color.r +
        matrix.m11 * color.g +
        matrix.m12 * color.b,

        matrix.m20 * color.r +
        matrix.m21 * color.g +
        matrix.m22 * color.b
    );
}


pragma(inline, true)
private void writeMatrix(T)(
    ref LinearSRgb!T output,
    const ref Matrix3!T matrix,
    T r,
    T g,
    T b
)
@safe pure nothrow @nogc
{
    output.r =
        matrix.m00 * r +
        matrix.m01 * g +
        matrix.m02 * b;

    output.g =
        matrix.m10 * r +
        matrix.m11 * g +
        matrix.m12 * b;

    output.b =
        matrix.m20 * r +
        matrix.m21 * g +
        matrix.m22 * b;
}


pragma(inline, true)
private void applyMatrixIntoExact(T)(
    const ref Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        writeMatrix(
            output[i],
            matrix,
            r,
            g,
            b
        );
    }
}


pragma(inline, true)
private void applyBrettelIntoExact(T)(
    const ref Matrix3!T first,
    const ref Matrix3!T second,
    T nr,
    T ng,
    T nb,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        const matrix =
            r * nr +
            g * ng +
            b * nb >= cast(T)0
                ? first
                : second;

        writeMatrix(
            output[i],
            matrix,
            r,
            g,
            b
        );
    }
}


private Matrix3!T castMatrix(T)(Matrix3!double matrix)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        cast(T)matrix.m00,
        cast(T)matrix.m01,
        cast(T)matrix.m02,
        cast(T)matrix.m10,
        cast(T)matrix.m11,
        cast(T)matrix.m12,
        cast(T)matrix.m20,
        cast(T)matrix.m21,
        cast(T)matrix.m22
    );
}


private Matrix3!T interpolateMatrix(T)(
    Matrix3!T first,
    Matrix3!T second,
    T alpha
)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        first.m00 + (second.m00 - first.m00) * alpha,
        first.m01 + (second.m01 - first.m01) * alpha,
        first.m02 + (second.m02 - first.m02) * alpha,

        first.m10 + (second.m10 - first.m10) * alpha,
        first.m11 + (second.m11 - first.m11) * alpha,
        first.m12 + (second.m12 - first.m12) * alpha,

        first.m20 + (second.m20 - first.m20) * alpha,
        first.m21 + (second.m21 - first.m21) * alpha,
        first.m22 + (second.m22 - first.m22) * alpha
    );
}


private enum Matrix3!double brettelProtan1 =
    Matrix3!double(
         0.14980,  1.19548, -0.34528,
         0.10764,  0.84864,  0.04372,
         0.00384, -0.00540,  1.00156
    );

private enum Matrix3!double brettelProtan2 =
    Matrix3!double(
         0.14570,  1.16172, -0.30742,
         0.10816,  0.85291,  0.03892,
         0.00386, -0.00524,  1.00139
    );

private enum Matrix3!double brettelDeutan1 =
    Matrix3!double(
         0.36477,  0.86381, -0.22858,
         0.26294,  0.64245,  0.09462,
        -0.02006,  0.02728,  0.99278
    );

private enum Matrix3!double brettelDeutan2 =
    Matrix3!double(
         0.37298,  0.88166, -0.25464,
         0.25954,  0.63506,  0.10540,
        -0.01980,  0.02784,  0.99196
    );

private enum Matrix3!double brettelTritan1 =
    Matrix3!double(
         1.01277,  0.13548, -0.14826,
        -0.01243,  0.86812,  0.14431,
         0.07589,  0.80500,  0.11911
    );

private enum Matrix3!double brettelTritan2 =
    Matrix3!double(
         0.93678,  0.18979, -0.12657,
         0.06154,  0.81526,  0.12320,
        -0.37562,  1.12767,  0.24796
    );

private enum Matrix3!double vienotProtan =
    Matrix3!double(
        0.11238,  0.88762, 0.0,
        0.11238,  0.88762, 0.0,
        0.00401, -0.00401, 1.0
    );

private enum Matrix3!double vienotDeutan =
    Matrix3!double(
         0.29275, 0.70725, 0.0,
         0.29275, 0.70725, 0.0,
        -0.02234, 0.02234, 1.0
    );


/**
 * Prepared Brettel 1997 full-dichromat transform for repeated application.
 *
 * The value owns only the two typed projection matrices and separation-plane
 * coefficients required by the selected deficiency. It allocates nothing and
 * carries no image, storage, threading, or gamut policy.
 *
 * Obtain a valid value with `prepareBrettel1997Dichromat`. `.init` is a
 * detectably invalid transform whose floating-point coefficients are NaN;
 * applying it produces NaN components rather than a plausible simulation.
 */
struct PreparedBrettel1997Dichromat(T)
if (is(T == float) || is(T == double))
{
    private Matrix3!T first;
    private Matrix3!T second;
    private T nr;
    private T ng;
    private T nb;

    /**
     * Applies the prepared transform to one linear-light sRGB color.
     */
    LinearSRgb!T apply(
        LinearSRgb!T color
    ) const
    @safe pure nothrow @nogc
    {
        const matrix =
            color.r * nr +
            color.g * ng +
            color.b * nb >= cast(T)0
                ? first
                : second;

        return applyMatrix(
            matrix,
            color
        );
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        enum prepared =
            prepareBrettel1997Dichromat!double(
                CvdDeficiency.protan
            );

        enum transformed =
            prepared.apply(
                LinearSRgbd(
                    0.2,
                    0.4,
                    0.7
                )
            );

        static assert(transformed.r == transformed.r);
    }

    /**
     * Applies the prepared transform to fixed-cardinality caller-owned storage.
     *
     * Exact in-place use is supported. Distinct source and destination arrays
     * are also supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N).
     */
    void applyInto(size_t N)(
        ref const LinearSRgb!T[N] input,
        ref LinearSRgb!T[N] output
    ) const
    @safe pure nothrow @nogc
    {
        static if (usePreparedLocalSnapshot)
        {
            const localFirst = first;
            const localSecond = second;
            const localNr = nr;
            const localNg = ng;
            const localNb = nb;

            applyBrettelIntoExact(
                localFirst,
                localSecond,
                localNr,
                localNg,
                localNb,
                input[],
                output[]
            );
        }
        else
        {
            applyBrettelIntoExact(
                first,
                second,
                nr,
                ng,
                nb,
                input[],
                output[]
            );
        }
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const prepared =
            prepareBrettel1997Dichromat!double(
                CvdDeficiency.deutan
            );

        const LinearSRgbd[2] input =
        [
            LinearSRgbd(0.2, 0.4, 0.7),
            LinearSRgbd(0.7, 0.4, 0.2)
        ];

        LinearSRgbd[2] output;

        prepared.applyInto(
            input,
            output
        );

        assert(output[0].r == output[0].r);
    }

    /**
     * Applies the prepared transform to runtime-sized caller-owned storage.
     *
     * Returns `false` and performs no writes when the input/output lengths do
     * not match. An empty pair is a successful empty operation. Exact in-place
     * use is supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N) on success and O(1) on a length mismatch.
     */
    bool tryApplyInto(
        const(LinearSRgb!T)[] input,
        LinearSRgb!T[] output
    ) const
    @safe pure nothrow @nogc
    {
        if (input.length != output.length)
            return false;

        static if (usePreparedLocalSnapshot)
        {
            const localFirst = first;
            const localSecond = second;
            const localNr = nr;
            const localNg = ng;
            const localNb = nb;

            applyBrettelIntoExact(
                localFirst,
                localSecond,
                localNr,
                localNg,
                localNb,
                input,
                output
            );
        }
        else
        {
            applyBrettelIntoExact(
                first,
                second,
                nr,
                ng,
                nb,
                input,
                output
            );
        }

        return true;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const prepared =
            prepareBrettel1997Dichromat!double(
                CvdDeficiency.tritan
            );

        LinearSRgbd[1] input =
        [
            LinearSRgbd(
                0.2,
                0.4,
                0.7
            )
        ];

        LinearSRgbd[2] output =
        [
            LinearSRgbd(1, 1, 1),
            LinearSRgbd(1, 1, 1)
        ];

        const before =
            output;

        assert(
            !prepared.tryApplyInto(
                input[],
                output[]
            )
        );

        assert(output == before);
    }
}


/**
 * Prepares one Brettel 1997 full-dichromat transform for repeated use.
 */
PreparedBrettel1997Dichromat!T prepareBrettel1997Dichromat(T)(
    CvdDeficiency deficiency
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    final switch (deficiency)
    {
        case CvdDeficiency.protan:
            return PreparedBrettel1997Dichromat!T(
                castMatrix!T(brettelProtan1),
                castMatrix!T(brettelProtan2),
                cast(T)0.00048,
                cast(T)0.00393,
                cast(T)-0.00441
            );

        case CvdDeficiency.deutan:
            return PreparedBrettel1997Dichromat!T(
                castMatrix!T(brettelDeutan1),
                castMatrix!T(brettelDeutan2),
                cast(T)-0.00281,
                cast(T)-0.00611,
                cast(T)0.00892
            );

        case CvdDeficiency.tritan:
            return PreparedBrettel1997Dichromat!T(
                castMatrix!T(brettelTritan1),
                castMatrix!T(brettelTritan2),
                cast(T)0.03901,
                cast(T)-0.02788,
                cast(T)-0.01113
            );
    }
}

///
@safe pure nothrow @nogc unittest
{
    enum prepared =
        prepareBrettel1997Dichromat!double(
            CvdDeficiency.protan
        );

    enum transformed =
        prepared.apply(
            LinearSRgbd(
                0.2,
                0.4,
                0.7
            )
        );

    static assert(transformed.g == transformed.g);
}


/**
 * Prepared Viénot 1999 protan/deutan transform for repeated application.
 *
 * The selected 3x3 matrix is converted to the consumer scalar type once and
 * then reused for every color. No clipping, gamut mapping, or allocation is
 * introduced.
 *
 * Obtain a valid value with `prepareVienot1999Dichromat`. `.init` is a
 * detectably invalid transform whose coefficients are NaN; applying it
 * produces NaN components.
 */
struct PreparedVienot1999Dichromat(T)
if (is(T == float) || is(T == double))
{
    private Matrix3!T matrix;

    /// Applies the prepared transform to one linear-light sRGB color.
    LinearSRgb!T apply(
        LinearSRgb!T color
    ) const
    @safe pure nothrow @nogc
    {
        return applyMatrix(
            matrix,
            color
        );
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        enum prepared =
            prepareVienot1999Dichromat!double(
                RedGreenCvdDeficiency.deutan
            );

        enum transformed =
            prepared.apply(
                LinearSRgbd(
                    0.2,
                    0.4,
                    0.7
                )
            );

        static assert(transformed.b == transformed.b);
    }

    /**
     * Applies the prepared transform to fixed-cardinality caller-owned storage.
     *
     * Exact in-place use is supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N).
     */
    void applyInto(size_t N)(
        ref const LinearSRgb!T[N] input,
        ref LinearSRgb!T[N] output
    ) const
    @safe pure nothrow @nogc
    {
        static if (usePreparedLocalSnapshot)
        {
            const localMatrix = matrix;

            applyMatrixIntoExact(
                localMatrix,
                input[],
                output[]
            );
        }
        else
        {
            applyMatrixIntoExact(
                matrix,
                input[],
                output[]
            );
        }
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const prepared =
            prepareVienot1999Dichromat!double(
                RedGreenCvdDeficiency.protan
            );

        const LinearSRgbd[2] input =
        [
            LinearSRgbd(0.2, 0.4, 0.7),
            LinearSRgbd(0.7, 0.4, 0.2)
        ];

        LinearSRgbd[2] output;

        prepared.applyInto(
            input,
            output
        );

        assert(output[1].r == output[1].r);
    }

    /**
     * Applies the prepared transform to runtime-sized caller-owned storage.
     *
     * Returns `false` and performs no writes on a length mismatch. Exact
     * in-place use is supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N) on success and O(1) on a length mismatch.
     */
    bool tryApplyInto(
        const(LinearSRgb!T)[] input,
        LinearSRgb!T[] output
    ) const
    @safe pure nothrow @nogc
    {
        if (input.length != output.length)
            return false;

        static if (usePreparedLocalSnapshot)
        {
            const localMatrix = matrix;

            applyMatrixIntoExact(
                localMatrix,
                input,
                output
            );
        }
        else
        {
            applyMatrixIntoExact(
                matrix,
                input,
                output
            );
        }

        return true;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const prepared =
            prepareVienot1999Dichromat!double(
                RedGreenCvdDeficiency.deutan
            );

        LinearSRgbd[1] input =
        [
            LinearSRgbd(
                0.2,
                0.4,
                0.7
            )
        ];

        LinearSRgbd[2] output;

        assert(
            !prepared.tryApplyInto(
                input[],
                output[]
            )
        );
    }
}


/**
 * Prepares one Viénot 1999 protan/deutan transform for repeated use.
 */
PreparedVienot1999Dichromat!T prepareVienot1999Dichromat(T)(
    RedGreenCvdDeficiency deficiency
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    final switch (deficiency)
    {
        case RedGreenCvdDeficiency.protan:
            return PreparedVienot1999Dichromat!T(
                castMatrix!T(vienotProtan)
            );

        case RedGreenCvdDeficiency.deutan:
            return PreparedVienot1999Dichromat!T(
                castMatrix!T(vienotDeutan)
            );
    }
}

///
@safe pure nothrow @nogc unittest
{
    enum prepared =
        prepareVienot1999Dichromat!double(
            RedGreenCvdDeficiency.protan
        );

    enum transformed =
        prepared.apply(
            LinearSRgbd(
                0.2,
                0.4,
                0.7
            )
        );

    static assert(transformed.r == transformed.r);
}


/**
 * Applies the Brettel, Viénot & Mollon (1997) full-dichromat transform.
 *
 * The operation uses the independently validated two-plane linear-sRGB
 * projection for the selected deficiency. It preserves extended linear values
 * and performs no clipping or gamut mapping.
 *
 * NaN and infinity are not sanitized; ordinary IEEE arithmetic remains
 * visible in the result.
 *
 * Params:
 *     color = Linear-light sRGB value to transform.
 *     deficiency = Protan, deutan, or tritan dichromat family.
 *
 * Returns:
 *     The transformed linear-light sRGB value.
 *
 * Repeated_Use:
 *     Prefer `prepareBrettel1997Dichromat` when applying the same deficiency
 *     to multiple colors.
 *
 * Standards:
 *     Brettel, Viénot & Mollon (1997), using the validated modern-sRGB
 *     precomputed projection matrices described by the project research.
 */
LinearSRgb!T brettel1997Dichromat(T)(
    LinearSRgb!T color,
    CvdDeficiency deficiency
)
@safe pure nothrow @nogc
{
    return
        prepareBrettel1997Dichromat!T(
            deficiency
        )
        .apply(color);
}

///
@safe pure nothrow @nogc unittest
{
    enum input = LinearSRgbd(0.2, 0.4, 0.7);
    enum transformed =
        input.brettel1997Dichromat(
            CvdDeficiency.protan
        );

    static assert(
        transformed.r > 0.278633 &&
        transformed.r < 0.278635
    );
    static assert(
        transformed.g > 0.390039 &&
        transformed.g < 0.390041
    );
    static assert(
        transformed.b > 0.699648 &&
        transformed.b < 0.699650
    );
}


/**
 * Applies the Viénot, Brettel & Mollon (1999) full-deficiency display
 * transform for protan or deutan dichromacy.
 *
 * The operation is a single 3x3 transform in linear-light sRGB. Tritan is not
 * part of this production contract; use the Brettel 1997 transform when a
 * promoted tritan dichromat simulation is required.
 *
 * The transform preserves extended values and does not clip or gamut-map.
 * NaN and infinity remain visible through ordinary IEEE arithmetic.
 *
 * Params:
 *     color = Linear-light sRGB value to transform.
 *     deficiency = Protan or deutan family.
 *
 * Returns:
 *     The transformed linear-light sRGB value.
 *
 * Repeated_Use:
 *     Prefer `prepareVienot1999Dichromat` when applying the same deficiency
 *     to multiple colors.
 *
 * Standards:
 *     Viénot, Brettel & Mollon (1999), using the independently validated
 *     modern-sRGB matrices preserved by the project research.
 */
LinearSRgb!T vienot1999Dichromat(T)(
    LinearSRgb!T color,
    RedGreenCvdDeficiency deficiency
)
@safe pure nothrow @nogc
{
    return
        prepareVienot1999Dichromat!T(
            deficiency
        )
        .apply(color);
}

///
@safe pure nothrow @nogc unittest
{
    enum input = LinearSRgbd(0.2, 0.4, 0.7);
    enum transformed =
        input.vienot1999Dichromat(
            RedGreenCvdDeficiency.deutan
        );

    static assert(
        transformed.r > 0.341449 &&
        transformed.r < 0.341451
    );
    static assert(
        transformed.g > 0.341449 &&
        transformed.g < 0.341451
    );
    static assert(
        transformed.b > 0.704467 &&
        transformed.b < 0.704469
    );
}


private enum Matrix3!double identityMatrix =
    Matrix3!double(
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    );

private enum Matrix3!double[11] machadoProtanTable =
[
    identityMatrix,
    Matrix3!double(.856167,.182038,-.038205,.029342,.955115,.015544,-.002880,-.001563,1.004443),
    Matrix3!double(.734766,.334872,-.069637,.051840,.919198,.028963,-.004928,-.004209,1.009137),
    Matrix3!double(.630323,.465641,-.095964,.069181,.890046,.040773,-.006308,-.007724,1.014032),
    Matrix3!double(.539009,.579343,-.118352,.082546,.866121,.051332,-.007136,-.011959,1.019095),
    Matrix3!double(.458064,.679578,-.137642,.092785,.846313,.060902,-.007494,-.016807,1.024301),
    Matrix3!double(.385450,.769005,-.154455,.100526,.829802,.069673,-.007442,-.022190,1.029632),
    Matrix3!double(.319627,.849633,-.169261,.106241,.815969,.077790,-.007025,-.028051,1.035076),
    Matrix3!double(.259411,.923008,-.182420,.110296,.804340,.085364,-.006276,-.034346,1.040622),
    Matrix3!double(.203876,.990338,-.194214,.112975,.794542,.092483,-.005222,-.041043,1.046265),
    Matrix3!double(.152286,1.052583,-.204868,.114503,.786281,.099216,-.003882,-.048116,1.051998)
];

private enum Matrix3!double[11] machadoDeutanTable =
[
    identityMatrix,
    Matrix3!double(.866435,.177704,-.044139,.049567,.939063,.011370,-.003453,.007233,.996220),
    Matrix3!double(.760729,.319078,-.079807,.090568,.889315,.020117,-.006027,.013325,.992702),
    Matrix3!double(.675425,.433850,-.109275,.125303,.847755,.026942,-.007950,.018572,.989378),
    Matrix3!double(.605511,.528560,-.134071,.155318,.812366,.032316,-.009376,.023176,.986200),
    Matrix3!double(.547494,.607765,-.155259,.181692,.781742,.036566,-.010410,.027275,.983136),
    Matrix3!double(.498864,.674741,-.173604,.205199,.754872,.039929,-.011131,.030969,.980162),
    Matrix3!double(.457771,.731899,-.189670,.226409,.731012,.042579,-.011595,.034333,.977261),
    Matrix3!double(.422823,.781057,-.203881,.245752,.709602,.044646,-.011843,.037423,.974421),
    Matrix3!double(.392952,.823610,-.216562,.263559,.690210,.046232,-.011910,.040281,.971630),
    Matrix3!double(.367322,.860646,-.227968,.280085,.672501,.047413,-.011820,.042940,.968881)
];


private Matrix3!T[11] castMatrixTable(T)(
    Matrix3!double[11] table
)
@safe pure nothrow @nogc
{
    Matrix3!T[11] result;

    foreach (i; 0 .. table.length)
    {
        result[i] =
            castMatrix!T(
                table[i]
            );
    }

    return result;
}


/*
 * R7.4.12 scalar-call qualification found that repeated runtime conversion of
 * Machado's published double tables into the consumer scalar type is material
 * on every supported compiler. Keep target-scalar runtime tables in read-only
 * storage while preserving the canonical double manifest tables for CTFE.
 *
 * Viénot and Brettel deliberately remain unchanged: the same research found
 * compiler/workload regressions for those models.
 */
private immutable Matrix3!float[11] machadoProtanFloatTable =
    castMatrixTable!float(
        machadoProtanTable
    );

private immutable Matrix3!float[11] machadoDeutanFloatTable =
    castMatrixTable!float(
        machadoDeutanTable
    );

private immutable Matrix3!double[11] machadoProtanDoubleTable =
    machadoProtanTable;

private immutable Matrix3!double[11] machadoDeutanDoubleTable =
    machadoDeutanTable;


private bool validMachadoSeverity(T)(T severity)
@safe pure nothrow @nogc
{
    // Ordered comparisons reject NaN and both infinities.
    return
        severity >= cast(T)0 &&
        severity <= cast(T)1;
}


private Matrix3!T matrixAtSeverity(T, alias table)(T severity)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    if (lower >= 10)
        return castMatrix!T(table[10]);

    const T alpha =
        scaled - cast(T)lower;

    return interpolateMatrix(
        castMatrix!T(table[lower]),
        castMatrix!T(table[lower + 1]),
        alpha
    );
}


private Matrix3!T matrixAtSeverityRuntime(T)(
    const ref Matrix3!T[11] table,
    T severity
)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    if (lower >= 10)
        return table[10];

    const T alpha =
        scaled - cast(T)lower;

    return interpolateMatrix(
        table[lower],
        table[lower + 1],
        alpha
    );
}


private Matrix3!T machadoProtanAtSeverity(T)(T severity)
@safe pure nothrow @nogc
{
    if (__ctfe)
    {
        return matrixAtSeverity!(
            T,
            machadoProtanTable
        )(
            severity
        );
    }

    static if (is(T == float))
    {
        return matrixAtSeverityRuntime(
            machadoProtanFloatTable,
            severity
        );
    }
    else
    {
        return matrixAtSeverityRuntime(
            machadoProtanDoubleTable,
            severity
        );
    }
}


private Matrix3!T machadoDeutanAtSeverity(T)(T severity)
@safe pure nothrow @nogc
{
    if (__ctfe)
    {
        return matrixAtSeverity!(
            T,
            machadoDeutanTable
        )(
            severity
        );
    }

    static if (is(T == float))
    {
        return matrixAtSeverityRuntime(
            machadoDeutanFloatTable,
            severity
        );
    }
    else
    {
        return matrixAtSeverityRuntime(
            machadoDeutanDoubleTable,
            severity
        );
    }
}


private Matrix3!T machadoMatrixAtSeverity(T)(
    RedGreenCvdDeficiency deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    final switch (deficiency)
    {
        case RedGreenCvdDeficiency.protan:
            return machadoProtanAtSeverity!T(
                severity
            );

        case RedGreenCvdDeficiency.deutan:
            return machadoDeutanAtSeverity!T(
                severity
            );
    }
}


/**
 * Prepared Machado 2009 protan/deutan transform for repeated application.
 *
 * A valid value contains one severity-interpolated 3x3 matrix in the consumer
 * scalar type. Use `tryPrepareMachado2009` to construct it from runtime
 * severity input.
 *
 * `.init` is the documented invalid state. Its matrix coefficients are NaN,
 * so applying it produces NaN components rather than a plausible transformed
 * color.
 */
struct PreparedMachado2009(T)
if (is(T == float) || is(T == double))
{
    private Matrix3!T matrix;

    /// Applies the prepared transform to one linear-light sRGB color.
    LinearSRgb!T apply(
        LinearSRgb!T color
    ) const
    @safe pure nothrow @nogc
    {
        return applyMatrix(
            matrix,
            color
        );
    }

    /**
     * Applies the prepared transform to fixed-cardinality caller-owned storage.
     *
     * Exact in-place use is supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N).
     */
    void applyInto(size_t N)(
        ref const LinearSRgb!T[N] input,
        ref LinearSRgb!T[N] output
    ) const
    @safe pure nothrow @nogc
    {
        static if (usePreparedLocalSnapshot)
        {
            const localMatrix = matrix;

            applyMatrixIntoExact(
                localMatrix,
                input[],
                output[]
            );
        }
        else
        {
            applyMatrixIntoExact(
                matrix,
                input[],
                output[]
            );
        }
    }

    /**
     * Applies the prepared transform to runtime-sized caller-owned storage.
     *
     * Returns `false` and performs no writes on a length mismatch. Exact
     * in-place use is supported.
     *
     * Allocation:
     *     Does not allocate.
     *
     * Complexity:
     *     O(N) on success and O(1) on a length mismatch.
     */
    bool tryApplyInto(
        const(LinearSRgb!T)[] input,
        LinearSRgb!T[] output
    ) const
    @safe pure nothrow @nogc
    {
        if (input.length != output.length)
            return false;

        static if (usePreparedLocalSnapshot)
        {
            const localMatrix = matrix;

            applyMatrixIntoExact(
                localMatrix,
                input,
                output
            );
        }
        else
        {
            applyMatrixIntoExact(
                matrix,
                input,
                output
            );
        }

        return true;
    }
}


/**
 * Prepares a Machado 2009 protan/deutan transform for repeated use.
 *
 * Severity uses the Machado model's own [0, 1] scale. On success, `prepared`
 * receives the interpolated matrix and the function returns `true`.
 *
 * Invalid severity, including NaN and infinity, returns `false`. Because the
 * destination is an `out` parameter, it is reset to
 * `PreparedMachado2009!T.init` on entry and therefore remains in the
 * documented invalid state after failure.
 */
bool tryPrepareMachado2009(T)(
    RedGreenCvdDeficiency deficiency,
    T severity,
    out PreparedMachado2009!T prepared
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    if (!validMachadoSeverity(severity))
        return false;

    prepared =
        PreparedMachado2009!T(
            machadoMatrixAtSeverity!T(
                deficiency,
                severity
            )
        );

    return true;
}


/**
 * Applies the Machado, Oliveira & Fernandes (2009) severity-dependent CVD
 * model for protan or deutan deficiency.
 *
 * Severity is specific to this model: 0 is the identity endpoint, 1 is the
 * full-deficiency endpoint, and intermediate values interpolate only between
 * adjacent published 0.1 reference matrices. It is not a generic CVD
 * severity parameter.
 *
 * Severity must be finite and in [0, 1]. Invalid severity is reported by
 * returning `LinearSRgb!T.init`, whose components are NaN; the value is not
 * silently clamped or normalized.
 *
 * The transform preserves extended color components and performs no clipping
 * or gamut mapping. NaN and infinity in the input remain visible through
 * ordinary IEEE arithmetic.
 *
 * The published Machado tritan table is deliberately not exposed by this
 * production callable because the retained research identifies a material
 * limitation for tritanopia/tritanomaly.
 *
 * Params:
 *     color = Linear-light sRGB value to transform.
 *     deficiency = Protan or deutan family.
 *     severity = Machado-model severity from 0 through 1 inclusive.
 *
 * Returns:
 *     The transformed linear-light sRGB value, or the natural invalid
 *     `LinearSRgb!T.init` value for invalid severity.
 *
 * Repeated_Use:
 *     Prefer `tryPrepareMachado2009` when applying one deficiency/severity
 *     pair to multiple colors.
 *
 * Standards:
 *     Machado, Oliveira & Fernandes (2009), using the cross-source-verified
 *     eleven-point reference matrix tables.
 */
LinearSRgb!T machado2009(T)(
    LinearSRgb!T color,
    RedGreenCvdDeficiency deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    if (!validMachadoSeverity(severity))
        return LinearSRgb!T.init;

    return applyMatrix(
        machadoMatrixAtSeverity!T(
            deficiency,
            severity
        ),
        color
    );
}

///
@safe pure nothrow @nogc unittest
{
    enum input = LinearSRgbd(0.2, 0.4, 0.7);

    enum half =
        input.machado2009(
            RedGreenCvdDeficiency.protan,
            0.5
        );

    static assert(
        half.r > 0.267093 &&
        half.r < 0.267096
    );
    static assert(
        half.g > 0.399712 &&
        half.g < 0.399715
    );
    static assert(
        half.b > 0.708788 &&
        half.b < 0.708791
    );

    enum identity =
        input.machado2009(
            RedGreenCvdDeficiency.deutan,
            0.0
        );

    static assert(identity == input);
}


@safe pure nothrow @nogc unittest
{
    // Invalid severity is visible and is never silently clamped.
    enum invalidLow =
        LinearSRgbd(0.2, 0.4, 0.7)
        .machado2009(
            RedGreenCvdDeficiency.protan,
            -0.01
        );

    enum invalidHigh =
        LinearSRgbd(0.2, 0.4, 0.7)
        .machado2009(
            RedGreenCvdDeficiency.deutan,
            1.01
        );

    enum invalidNaN =
        LinearSRgbd(0.2, 0.4, 0.7)
        .machado2009(
            RedGreenCvdDeficiency.protan,
            double.nan
        );

    static assert(invalidLow.r != invalidLow.r);
    static assert(invalidHigh.g != invalidHigh.g);
    static assert(invalidNaN.b != invalidNaN.b);
}


version (unittest)
{
    private import std.math :
        fabs,
        isInfinity,
        isNaN;

    private bool close(T)(
        T actual,
        T expected,
        T tolerance
    )
    @safe pure nothrow @nogc
    {
        return
            fabs(actual - expected) <= tolerance;
    }

    private void assertColorClose(T)(
        LinearSRgb!T actual,
        LinearSRgb!T expected,
        T tolerance
    )
    @safe pure nothrow @nogc
    {
        assert(close(actual.r, expected.r, tolerance));
        assert(close(actual.g, expected.g, tolerance));
        assert(close(actual.b, expected.b, tolerance));
    }


    private bool equivalentComponent(T)(
        T actual,
        T expected
    )
    @safe pure nothrow @nogc
    {
        if (isNaN(expected))
            return isNaN(actual);

        if (isInfinity(expected))
            return actual == expected;

        if (isNaN(actual) || isInfinity(actual))
            return false;

        const T tolerance =
            is(T == float)
                ? cast(T)2e-6
                : cast(T)1e-12;

        return fabs(actual - expected) <= tolerance;
    }


    private bool equivalentColor(T)(
        LinearSRgb!T actual,
        LinearSRgb!T expected
    )
    @safe pure nothrow @nogc
    {
        return
            equivalentComponent(actual.r, expected.r) &&
            equivalentComponent(actual.g, expected.g) &&
            equivalentComponent(actual.b, expected.b);
    }


    private bool preparedBatchProbe(T)()
    @safe pure nothrow @nogc
    {
        LinearSRgb!T[4] input =
        [
            LinearSRgb!T(
                cast(T)0.2,
                cast(T)0.4,
                cast(T)0.7
            ),
            LinearSRgb!T(
                cast(T)-0.25,
                cast(T)1.25,
                cast(T)2.0
            ),
            LinearSRgb!T(
                T.nan,
                cast(T)0.25,
                cast(T)0.75
            ),
            LinearSRgb!T(
                T.infinity,
                cast(T)0.25,
                -T.infinity
            )
        ];

        foreach (index; 0u .. 3u)
        {
            const deficiency =
                cast(CvdDeficiency)index;

            const prepared =
                prepareBrettel1997Dichromat!T(
                    deficiency
                );

            LinearSRgb!T[4] output;

            prepared.applyInto(
                input,
                output
            );

            foreach (i; 0 .. input.length)
            {
                if (!equivalentColor(
                    output[i],
                    input[i].brettel1997Dichromat(
                        deficiency
                    )
                ))
                {
                    return false;
                }
            }

            auto inPlace = input;

            prepared.applyInto(
                inPlace,
                inPlace
            );

            if (inPlace != output)
                return false;

            auto runtimeInPlace = input;

            if (!prepared.tryApplyInto(
                runtimeInPlace[],
                runtimeInPlace[]
            ))
            {
                return false;
            }

            if (runtimeInPlace != output)
                return false;
        }

        foreach (index; 0u .. 2u)
        {
            const deficiency =
                cast(RedGreenCvdDeficiency)index;

            const prepared =
                prepareVienot1999Dichromat!T(
                    deficiency
                );

            LinearSRgb!T[4] output;

            prepared.applyInto(
                input,
                output
            );

            foreach (i; 0 .. input.length)
            {
                if (!equivalentColor(
                    output[i],
                    input[i].vienot1999Dichromat(
                        deficiency
                    )
                ))
                {
                    return false;
                }
            }

            auto inPlace = input;

            prepared.applyInto(
                inPlace,
                inPlace
            );

            if (inPlace != output)
                return false;

            PreparedMachado2009!T machado;

            if (!tryPrepareMachado2009(
                deficiency,
                cast(T)0.65,
                machado
            ))
            {
                return false;
            }

            LinearSRgb!T[4] machadoOutput;

            machado.applyInto(
                input,
                machadoOutput
            );

            foreach (i; 0 .. input.length)
            {
                if (!equivalentColor(
                    machadoOutput[i],
                    input[i].machado2009(
                        deficiency,
                        cast(T)0.65
                    )
                ))
                {
                    return false;
                }
            }

            auto machadoInPlace = input;

            if (!machado.tryApplyInto(
                machadoInPlace[],
                machadoInPlace[]
            ))
            {
                return false;
            }

            if (machadoInPlace != machadoOutput)
                return false;
        }

        const sentinel =
            LinearSRgb!T(
                cast(T)0.11,
                cast(T)0.22,
                cast(T)0.33
            );

        LinearSRgb!T[2] mismatch =
        [
            sentinel,
            sentinel
        ];

        const vienot =
            prepareVienot1999Dichromat!T(
                RedGreenCvdDeficiency.protan
            );

        if (vienot.tryApplyInto(
            input[0 .. 1],
            mismatch[]
        ))
        {
            return false;
        }

        if (
            mismatch[0] != sentinel ||
            mismatch[1] != sentinel
        )
        {
            return false;
        }

        PreparedMachado2009!T invalidPrepared;

        if (tryPrepareMachado2009(
            RedGreenCvdDeficiency.protan,
            cast(T)-0.01,
            invalidPrepared
        ))
        {
            return false;
        }

        const invalidColor =
            invalidPrepared.apply(input[0]);

        if (
            !isNaN(invalidColor.r) ||
            !isNaN(invalidColor.g) ||
            !isNaN(invalidColor.b)
        )
        {
            return false;
        }

        const invalidVienot =
            PreparedVienot1999Dichromat!T.init
            .apply(input[0]);

        const invalidBrettel =
            PreparedBrettel1997Dichromat!T.init
            .apply(input[0]);

        if (
            !isNaN(invalidVienot.r) ||
            !isNaN(invalidBrettel.r)
        )
        {
            return false;
        }

        LinearSRgb!T[0] emptyInput;
        LinearSRgb!T[0] emptyOutput;

        return vienot.tryApplyInto(
            emptyInput[],
            emptyOutput[]
        );
    }

    @safe pure nothrow @nogc unittest
    {
        static assert(preparedBatchProbe!float());
        static assert(preparedBatchProbe!double());

        assert(preparedBatchProbe!float());
        assert(preparedBatchProbe!double());
    }


    @safe pure nothrow @nogc unittest
    {
        // Fixed independent reference vectors from R7.4.1.
        const input =
            LinearSRgbd(0.2, 0.4, 0.7);

        assertColorClose(
            input.brettel1997Dichromat(
                CvdDeficiency.protan
            ),
            LinearSRgbd(
                0.278634,
                0.390040,
                0.699649
            ),
            1e-6
        );

        assertColorClose(
            input.brettel1997Dichromat(
                CvdDeficiency.deutan
            ),
            LinearSRgbd(
                0.258472,
                0.375802,
                0.701846
            ),
            1e-6
        );

        assertColorClose(
            input.brettel1997Dichromat(
                CvdDeficiency.tritan
            ),
            LinearSRgbd(
                0.174673,
                0.424652,
                0.549516
            ),
            1e-6
        );

        assertColorClose(
            input.vienot1999Dichromat(
                RedGreenCvdDeficiency.protan
            ),
            LinearSRgbd(
                0.377524,
                0.377524,
                0.699198
            ),
            1e-6
        );

        assertColorClose(
            input.vienot1999Dichromat(
                RedGreenCvdDeficiency.deutan
            ),
            LinearSRgbd(
                0.341450,
                0.341450,
                0.704468
            ),
            1e-6
        );
    }

    @safe pure nothrow @nogc unittest
    {
        // Machado table points are fixed regression data from the cross-source
        // verified 11-point tables.
        const input =
            LinearSRgbd(0.2, 0.4, 0.7);

        assertColorClose(
            input.machado2009(
                RedGreenCvdDeficiency.protan,
                0.5
            ),
            LinearSRgbd(
                0.2670946,
                0.3997136,
                0.7087891
            ),
            1e-12
        );

        assertColorClose(
            input.machado2009(
                RedGreenCvdDeficiency.deutan,
                1.0
            ),
            LinearSRgbd(
                0.2581452,
                0.3582065,
                0.6930287
            ),
            1e-12
        );
    }

    @safe pure nothrow @nogc unittest
    {
        // The transformation layer preserves extended and special values
        // instead of applying hidden gamut policy.
        const extended =
            LinearSRgbd(-0.25, 1.25, 2.0)
            .vienot1999Dichromat(
                RedGreenCvdDeficiency.protan
            );

        assert(
            extended.r < 0.0 ||
            extended.g > 1.0 ||
            extended.b > 1.0
        );

        const special =
            LinearSRgbd(
                double.nan,
                double.infinity,
                -double.infinity
            )
            .brettel1997Dichromat(
                CvdDeficiency.deutan
            );

        assert(
            isNaN(special.r) ||
            isNaN(special.g) ||
            isNaN(special.b)
        );

        assert(
            isInfinity(special.r) ||
            isInfinity(special.g) ||
            isInfinity(special.b) ||
            isNaN(special.r) ||
            isNaN(special.g) ||
            isNaN(special.b)
        );
    }

    @safe pure nothrow @nogc unittest
    {
        // Float and double follow the separately qualified arithmetic path.
        const sampleD =
            LinearSRgbd(0.17, 0.59, 0.33);

        const sampleF =
            LinearSRgb!float(
                0.17f,
                0.59f,
                0.33f
            );

        const doubleResult =
            sampleD.machado2009(
                RedGreenCvdDeficiency.protan,
                0.7
            );

        const floatResult =
            sampleF.machado2009(
                RedGreenCvdDeficiency.protan,
                0.7f
            );

        assert(
            fabs(
                cast(double)floatResult.r -
                doubleResult.r
            ) < 2e-6
        );
        assert(
            fabs(
                cast(double)floatResult.g -
                doubleResult.g
            ) < 2e-6
        );
        assert(
            fabs(
                cast(double)floatResult.b -
                doubleResult.b
            ) < 2e-6
        );
    }

    @safe pure nothrow @nogc unittest
    {
        /*
         * Consumer-composition evidence: color-d exposes transformation and
         * measurement primitives independently. The consumer owns any
         * threshold or accessibility decision.
         */
        import color.difference : deltaEOK;
        import color.oklab : toOklab;
        import color.wcag : wcag2ContrastRatio;
        import color.xyz : toXyzD65;

        const original =
            LinearSRgbd(0.2, 0.4, 0.7);

        const simulated =
            original.vienot1999Dichromat(
                RedGreenCvdDeficiency.deutan
            );

        const perceptualDistance =
            original
            .toXyzD65
            .toOklab
            .deltaEOK(
                simulated
                .toXyzD65
                .toOklab
            );

        assert(perceptualDistance >= 0.0);

        const neutral =
            LinearSRgbd(0.5, 0.5, 0.5)
            .vienot1999Dichromat(
                RedGreenCvdDeficiency.protan
            );

        const contrast =
            neutral.wcag2ContrastRatio(
                LinearSRgbd(0, 0, 0)
            );

        assert(contrast.valid);
        assert(contrast.value > 1.0);
    }

    static assert(!__traits(compiles,
        vienot1999Dichromat(
            LinearSRgbd(0.2, 0.4, 0.7),
            CvdDeficiency.tritan
        )
    ));

    static assert(!__traits(compiles,
        machado2009(
            LinearSRgbd(0.2, 0.4, 0.7),
            CvdDeficiency.tritan,
            1.0
        )
    ));

    static assert(!__traits(compiles,
        brettel1997Dichromat(
            LinearSRgbd(0.2, 0.4, 0.7),
            RedGreenCvdDeficiency.protan
        )
    ));
}
