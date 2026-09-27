// Production-path validation and benchmark for XYZ D65 -> linear-sRGB
// extreme-finite hardening.
//
// Baseline duplicates the pre-fix direct inverse matrix. Production calls the
// public toLinearSRgb implementation from the current branch.

module xyz_linear_rgb_production_probe;

import color :
    LinearSRgb,
    XyzD65,
    toLinearSRgb;

import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln, writeln;

template ReferenceScalar(T)
{
    static if (is(T == float))
        alias ReferenceScalar = double;
    else
        alias ReferenceScalar = real;
}

private R ratio(R)(long numerator, long denominator)
{
    return cast(R)numerator / cast(R)denominator;
}

private LinearSRgb!T baseline(T)(XyzD65!T xyz)
{
    return LinearSRgb!T(
        ratio!T(12831,    3959)   * xyz.x +
        ratio!T(-329,      214)   * xyz.y +
        ratio!T(-1974,    3959)   * xyz.z,

        ratio!T(-851781, 878810)  * xyz.x +
        ratio!T(1648619, 878810)  * xyz.y +
        ratio!T(36519,   878810)  * xyz.z,

        ratio!T(705,      12673)  * xyz.x +
        ratio!T(-2585,    12673)  * xyz.y +
        ratio!T(705,        667)  * xyz.z
    );
}

private struct Ref3(R)
{
    R r;
    R g;
    R b;
}

private Ref3!R reference(T, R)(XyzD65!T xyz)
{
    const R x = cast(R)xyz.x;
    const R y = cast(R)xyz.y;
    const R z = cast(R)xyz.z;

    return Ref3!R(
        ratio!R(12831,    3959)   * x +
        ratio!R(-329,      214)   * y +
        ratio!R(-1974,    3959)   * z,

        ratio!R(-851781, 878810)  * x +
        ratio!R(1648619, 878810)  * y +
        ratio!R(36519,   878810)  * z,

        ratio!R(705,      12673)  * x +
        ratio!R(-2585,    12673)  * y +
        ratio!R(705,        667)  * z
    );
}

private bool finite(T)(T value)
{
    return
        value > -T.infinity &&
        value < T.infinity;
}

private bool outputFinite(T)(LinearSRgb!T value)
{
    return
        finite(value.r) &&
        finite(value.g) &&
        finite(value.b);
}

private bool representableAs(T, R)(R value)
{
    return
        value == value &&
        value <= cast(R)T.max &&
        value >= -cast(R)T.max;
}

private bool referenceFits(T, R)(Ref3!R value)
{
    return
        representableAs!T(value.r) &&
        representableAs!T(value.g) &&
        representableAs!T(value.b);
}

private real absolute(real value)
{
    return value < 0 ? -value : value;
}

private real referenceError(T, R)(T actual, R expected)
{
    return absolute(
        cast(real)actual -
        cast(real)expected
    );
}

private uint nextRandom(ref uint state)
{
    state =
        state * 1_664_525U +
        1_013_904_223U;

    return state;
}

private T ordinaryValue(T)(ref uint state)
{
    const uint bits =
        nextRandom(state) &
        0x00FF_FFFFU;

    const T unit =
        cast(T)bits /
        cast(T)0x00FF_FFFFU;

    return
        cast(T)-0.25 +
        cast(T)1.50 * unit;
}

enum validationSamples = 2_000_000;

private bool validateOrdinary(T)(string scalarName)
{
    alias R = ReferenceScalar!T;

    uint state = 0xC01D_0088U;
    size_t valueMismatches = 0;
    size_t productionBetter = 0;
    size_t equalError = 0;
    size_t productionWorse = 0;

    real baselineErrorSum = 0;
    real productionErrorSum = 0;
    real baselineMaxError = 0;
    real productionMaxError = 0;

    foreach (_; 0 .. validationSamples)
    {
        const auto xyz =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );

        const auto former = baseline(xyz);
        const auto current = xyz.toLinearSRgb;
        const auto refValue = reference!(T, R)(xyz);

        if (
            former.r != current.r ||
            former.g != current.g ||
            former.b != current.b
        )
        {
            ++valueMismatches;
        }

        static foreach (member; ["r", "g", "b"])
        {
            const real oldError =
                referenceError(
                    __traits(getMember, former, member),
                    __traits(getMember, refValue, member)
                );

            const real newError =
                referenceError(
                    __traits(getMember, current, member),
                    __traits(getMember, refValue, member)
                );

            baselineErrorSum += oldError;
            productionErrorSum += newError;

            if (oldError > baselineMaxError)
                baselineMaxError = oldError;

            if (newError > productionMaxError)
                productionMaxError = newError;

            if (newError < oldError)
                ++productionBetter;
            else if (newError > oldError)
                ++productionWorse;
            else
                ++equalError;
        }
    }

    const real componentCount =
        cast(real)validationSamples * 3;

    writefln(
        "%s ordinary: samples=%s value_mismatches=%s",
        scalarName,
        validationSamples,
        valueMismatches
    );

    writefln(
        "%s reference: better=%s equal=%s worse=%s old_mean=%s new_mean=%s old_max=%s new_max=%s",
        scalarName,
        productionBetter,
        equalError,
        productionWorse,
        baselineErrorSum / componentCount,
        productionErrorSum / componentCount,
        baselineMaxError,
        productionMaxError
    );

    static if (is(T == float))
    {
        return
            valueMismatches == 0 &&
            baselineErrorSum == productionErrorSum &&
            baselineMaxError == productionMaxError;
    }
    else
    {
        return
            productionErrorSum < baselineErrorSum &&
            productionMaxError < baselineMaxError &&
            productionBetter > productionWorse;
    }
}

private T scaledMax(T)(double factor)
{
    return cast(T)(
        cast(ReferenceScalar!T)T.max *
        cast(ReferenceScalar!T)factor
    );
}

private bool validateExtreme(T)(string scalarName)
{
    alias R = ReferenceScalar!T;

    const double[9] factors = [
        -1.0, -0.75, -0.50, -0.25,
         0.0,
         0.25, 0.50, 0.75, 1.0
    ];

    size_t representable = 0;
    size_t baselineAvoidable = 0;
    size_t productionAvoidable = 0;

    foreach (fx; factors)
    foreach (fy; factors)
    foreach (fz; factors)
    {
        const auto xyz =
            XyzD65!T(
                scaledMax!T(fx),
                scaledMax!T(fy),
                scaledMax!T(fz)
            );

        const auto refValue =
            reference!(T, R)(xyz);

        if (!referenceFits!T(refValue))
            continue;

        ++representable;

        if (!outputFinite(baseline(xyz)))
            ++baselineAvoidable;

        if (!outputFinite(xyz.toLinearSRgb))
            ++productionAvoidable;
    }

    writefln(
        "%s extreme: representable=%s baseline_avoidable=%s production_avoidable=%s",
        scalarName,
        representable,
        baselineAvoidable,
        productionAvoidable
    );

    return
        baselineAvoidable == 42 &&
        productionAvoidable == 0;
}

private bool sameClassification(T)(T first, T second)
{
    if (first != first)
        return second != second;

    if (first == T.infinity)
        return second == T.infinity;

    if (first == -T.infinity)
        return second == -T.infinity;

    return finite(second);
}

private bool validateSpecials(T)(string scalarName)
{
    const T nan = T.nan;
    const T inf = T.infinity;

    const XyzD65!T[8] values = [
        XyzD65!T(nan, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, nan, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, nan),
        XyzD65!T(inf, cast(T)0, cast(T)0),
        XyzD65!T(-inf, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, inf, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, -inf),
        XyzD65!T(inf, -inf, nan)
    ];

    size_t mismatches = 0;

    foreach (xyz; values)
    {
        const auto former = baseline(xyz);
        const auto current = xyz.toLinearSRgb;

        if (
            !sameClassification(former.r, current.r) ||
            !sameClassification(former.g, current.g) ||
            !sameClassification(former.b, current.b)
        )
        {
            ++mismatches;
        }
    }

    writefln(
        "%s nonfinite: samples=%s classification_mismatches=%s",
        scalarName,
        values.length,
        mismatches
    );

    return mismatches == 0;
}

private void characterizeSubnormal(T)(string scalarName)
{
    alias R = ReferenceScalar!T;

    const T tiny =
        T.min_normal /
        cast(T)2;

    const XyzD65!T[8] values = [
        XyzD65!T(tiny, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, tiny, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, tiny),
        XyzD65!T(-tiny, tiny, cast(T)0),
        XyzD65!T(tiny, -tiny, tiny),
        XyzD65!T(-tiny, -tiny, -tiny),
        XyzD65!T(T.min_normal, tiny, -tiny),
        XyzD65!T(-T.min_normal, -tiny, tiny)
    ];

    size_t valueMismatches = 0;
    size_t better = 0;
    size_t equal = 0;
    size_t worse = 0;

    foreach (xyz; values)
    {
        const auto former = baseline(xyz);
        const auto current = xyz.toLinearSRgb;
        const auto refValue = reference!(T, R)(xyz);

        if (
            former.r != current.r ||
            former.g != current.g ||
            former.b != current.b
        )
        {
            ++valueMismatches;
        }

        static foreach (member; ["r", "g", "b"])
        {
            const real oldError =
                referenceError(
                    __traits(getMember, former, member),
                    __traits(getMember, refValue, member)
                );

            const real newError =
                referenceError(
                    __traits(getMember, current, member),
                    __traits(getMember, refValue, member)
                );

            if (newError < oldError)
                ++better;
            else if (newError > oldError)
                ++worse;
            else
                ++equal;
        }
    }

    writefln(
        "%s subnormal: samples=%s value_mismatches=%s better=%s equal=%s worse=%s",
        scalarName,
        values.length,
        valueMismatches,
        better,
        equal,
        worse
    );
}

enum benchCount = 16_384;
enum repetitions = 800;
enum rounds = 13;

private double timeBaseline(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    foreach (value; values)
    {
        const auto result = baseline(value);
        checksum += result.r + result.g + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private double timeProduction(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    foreach (value; values)
    {
        const auto result = value.toLinearSRgb;
        checksum += result.r + result.g + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private double median(double[rounds] values)
{
    foreach (i; 1 .. values.length)
    {
        const double key = values[i];
        size_t j = i;

        while (j > 0 && values[j - 1] > key)
        {
            values[j] = values[j - 1];
            --j;
        }

        values[j] = key;
    }

    return values[values.length / 2];
}

private void benchmark(T)(string scalarName)
{
    XyzD65!T[benchCount] values;
    uint state = 0xC01D_0089U;

    foreach (ref value; values)
    {
        value =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );
    }

    double[rounds] ratios;
    T checksum = cast(T)0;

    foreach (round; 0 .. rounds)
    {
        double baselineNs;
        double productionNs;

        if ((round & 1) == 0)
        {
            baselineNs =
                timeBaseline(values[], checksum);

            productionNs =
                timeProduction(values[], checksum);
        }
        else
        {
            productionNs =
                timeProduction(values[], checksum);

            baselineNs =
                timeBaseline(values[], checksum);
        }

        ratios[round] =
            productionNs /
            baselineNs;

        writefln(
            "%s round %s: baseline=%.4f ns production=%.4f ns ratio=%.5f",
            scalarName,
            round + 1,
            baselineNs,
            productionNs,
            ratios[round]
        );
    }

    writefln(
        "%s median_ratio=%.5f checksum=%s",
        scalarName,
        median(ratios),
        checksum
    );
}

int main()
{
    writeln("=== color-d production XYZ -> linear-sRGB audit ===");

    bool ok = true;

    ok = validateOrdinary!double("double") && ok;
    ok = validateOrdinary!float("float") && ok;

    characterizeSubnormal!double("double");
    characterizeSubnormal!float("float");

    ok = validateSpecials!double("double") && ok;
    ok = validateSpecials!float("float") && ok;

    ok = validateExtreme!double("double") && ok;
    ok = validateExtreme!float("float") && ok;

    benchmark!double("double");
    benchmark!float("float");

    return ok ? 0 : 1;
}
