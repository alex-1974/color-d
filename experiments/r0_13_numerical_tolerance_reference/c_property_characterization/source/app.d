module app;

import c1_oklch_hue : runC1For;
import c2_alpha_compositing : runC2For;
import c3_interpolation : runC3For;
import c4_wcag : runC4For;
import std.stdio : writefln, writeln;

void main()
{
    writeln("=== color-d R0.13-C property characterization ===");
    writeln();

    writefln(
        "float  sizeof=%s mant_dig=%s epsilon=% .9g",
        float.sizeof,
        float.mant_dig,
        float.epsilon
    );
    writefln(
        "double sizeof=%s mant_dig=%s epsilon=% .17g",
        double.sizeof,
        double.mant_dig,
        double.epsilon
    );
    writefln(
        "real   sizeof=%s mant_dig=%s epsilon=% .21g",
        real.sizeof,
        real.mant_dig,
        real.epsilon
    );
    writefln(
        "real wider than double = %s",
        real.mant_dig > double.mant_dig
    );
    writeln();

    runC1For!float("float");
    runC1For!double("double");

    runC2For!float("float");
    runC2For!double("double");

    runC3For!float("float");
    runC3For!double("double");

    runC4For!float("float");
    runC4For!double("double");
}
