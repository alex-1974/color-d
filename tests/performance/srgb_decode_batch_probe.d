// Small reproducible benchmark for the reusable sRGB8 decode table.
//
// This compares the exact scalar transfer path with a caller-owned table over
// the same 8-bit corpus. It is intentionally a standalone probe, not a
// production benchmark contract.
module srgb_decode_batch_probe;

import color.rgb :
    SRgbd,
    SRgb8DecodeTable,
    toLinear,
    makeSRgb8DecodeTable;
import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln, writeln;

enum sampleCount = 4096;
enum repetitions = 2000;

private double scalarPass(const ubyte[sampleCount] values)
{
    double checksum = 0.0;

    foreach (repeat; 0 .. repetitions)
    {
        foreach (value; values)
        {
            const component = SRgbd(
                cast(double)value / 255.0,
                cast(double)value / 255.0,
                cast(double)value / 255.0
            ).toLinear.r;
            if (component != component)
                return double.nan;
            checksum += component;
        }
    }

    return checksum;
}

private double tablePass(
    const ubyte[sampleCount] values,
    const SRgb8DecodeTable!double table
)
{
    double checksum = 0.0;

    foreach (repeat; 0 .. repetitions)
    {
        foreach (value; values)
        {
            if (table[value] != table[value])
                return double.nan;
            checksum += table[value];
        }
    }

    return checksum;
}

int main()
{
    ubyte[sampleCount] values;
    foreach (i, ref value; values)
        value = cast(ubyte)(i & 255);

    const table = makeSRgb8DecodeTable!double();

    StopWatch scalarWatch;
    scalarWatch.start();
    const scalarChecksum = scalarPass(values);
    const scalarMilliseconds = scalarWatch.peek.total!"msecs";

    StopWatch tableWatch;
    tableWatch.start();
    const tableChecksum = tablePass(values, table);
    const tableMilliseconds = tableWatch.peek.total!"msecs";

    writeln("=== color-d reusable sRGB8 decode table benchmark ===");
    writefln("samples=%s repetitions=%s", sampleCount, repetitions);
    writefln("scalar_ms=%s checksum=%s", scalarMilliseconds, scalarChecksum);
    writefln("table_ms=%s checksum=%s", tableMilliseconds, tableChecksum);

    return scalarChecksum == tableChecksum ? 0 : 1;
}
