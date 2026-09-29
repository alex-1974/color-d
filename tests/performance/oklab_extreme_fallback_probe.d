// Production-path benchmark for the result-gated XYZ D65 -> Oklab
// extreme-finite fallback.
//
// The baseline duplicates the pre-fix direct transform. The candidate is the
// public production toOklab implementation from the current branch.

module oklab_extreme_fallback_probe;

import color :
    Oklab,
    XyzD65,
    toOklab;

import std.datetime.stopwatch : StopWatch;
import std.math : cbrt;
import std.stdio : writefln, writeln;

enum benchCount = 8_192;
enum repetitions = 200;
enum rounds = 7;
enum validationSamples = 1_000_000;

private Oklab!T directBaseline(T)(XyzD65!T xyz)
{
    const T l =
        cast(T)0.8190224379967030 * xyz.x +
        cast(T)0.3619062600528904 * xyz.y -
        cast(T)0.1288737815209879 * xyz.z;

    const T m =
        cast(T)0.0329836539323885 * xyz.x +
        cast(T)0.9292868615863434 * xyz.y +
        cast(T)0.0361446663506424 * xyz.z;

    const T s =
        cast(T)0.0481771893596242 * xyz.x +
        cast(T)0.2642395317527308 * xyz.y +
        cast(T)0.6335478284694309 * xyz.z;

    const T lp = cbrt(l);
    const T mp = cbrt(m);
    const T sp = cbrt(s);

    return Oklab!T(
        cast(T)0.2104542683093140 * lp +
        cast(T)0.7936177747023054 * mp -
        cast(T)0.0040720430116193 * sp,

        cast(T)1.9779985324311684 * lp -
        cast(T)2.4285922420485799 * mp +
        cast(T)0.4505937096174110 * sp,

        cast(T)0.0259040424655478 * lp +
        cast(T)0.7827717124575296 * mp -
        cast(T)0.8086757549230774 * sp
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

private bool finite(T)(T value)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private bool equalBitsByValue(T)(Oklab!T first, Oklab!T second)
{
    return
        first.l == second.l &&
        first.a == second.a &&
        first.b == second.b;
}

private bool validateOrdinary(T)(string scalarName)
{
    uint state = 0xC01D_0024U;

    foreach (_; 0 .. validationSamples)
    {
        const xyz =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );

        const baseline = directBaseline(xyz);
        const production = xyz.toOklab;

        if (!equalBitsByValue(baseline, production))
        {
            writeln(
                scalarName,
                " ordinary-path mismatch"
            );
            return false;
        }
    }

    writeln(
        scalarName,
        " ordinary validation: samples=",
        validationSamples,
        " mismatches=0"
    );

    return true;
}

private bool validateExtreme(T)(string scalarName)
{
    const auto result =
        XyzD65!T(
            T.max,
            T.max,
            -T.max
        ).toOklab;

    const bool ok =
        finite(result.l) &&
        finite(result.a) &&
        finite(result.b);

    writeln(
        scalarName,
        " extreme finite closure=",
        ok ? "PASS" : "FAIL"
    );

    return ok;
}

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
        const result = directBaseline(value);
        checksum += result.l + result.a + result.b;
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
        const result = value.toOklab;
        checksum += result.l + result.a + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private void benchmark(T)(string scalarName)
{
    XyzD65!T[benchCount] values;
    uint state = 0xC01D_0025U;

    foreach (ref value; values)
    {
        value =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );
    }

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

        writefln(
            "%s round %s: baseline=%.3f ns production=%.3f ns production_over_baseline=%.4f",
            scalarName,
            round + 1,
            baselineNs,
            productionNs,
            productionNs / baselineNs
        );
    }

    writeln(
        scalarName,
        " checksum=",
        checksum
    );
}

int main()
{
    writeln("=== color-d production Oklab fallback audit ===");

    if (!validateOrdinary!double("double"))
        return 1;

    if (!validateOrdinary!float("float"))
        return 1;

    if (!validateExtreme!double("double"))
        return 1;

    if (!validateExtreme!float("float"))
        return 1;

    benchmark!double("double");
    benchmark!float("float");

    return 0;
}
