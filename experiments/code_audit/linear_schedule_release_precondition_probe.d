// Characterization probe for the documented finite-endpoint precondition of
// color.tone.linearSchedule.
//
// This deliberately invokes the API outside its public contract in a release
// build, where assertions are disabled. The output is evidence only; it must
// not become a promised invalid-input result.

module linear_schedule_release_precondition_probe;

import color : linearSchedule;
import std.stdio : write, writeln;

private double parse(string text)
{
    if (text == "nan")
        return double.nan;
    if (text == "inf")
        return double.infinity;
    if (text == "-inf")
        return -double.infinity;
    if (text == "1")
        return 1.0;

    assert(0, "unsupported probe input");
}

private const(char)[] classify(double value)
{
    if (value != value)
        return "nan";
    if (value == double.infinity)
        return "+inf";
    if (value == -double.infinity)
        return "-inf";
    return "finite";
}

void main(string[] args)
{
    assert(args.length == 3);

    const double start = parse(args[1]);
    const double end = parse(args[2]);

    const values = linearSchedule!5(start, end);

    write(args[1], " -> ", args[2], ":");
    foreach (value; values)
        write(" ", classify(value));
    writeln();
}
