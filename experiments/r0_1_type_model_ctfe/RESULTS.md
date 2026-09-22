# R0.1 Results — Type Model and CTFE

## Status

PASS

Tested on x86_64 with:

- DMD, debug build
- LDC, release build

Both compilers produced the same observed layouts and successfully evaluated
the compile-time theme-generation tests.

## Observed layout

| Type | sizeof | alignof |
|---|---:|---:|
| `SRgb!float` | 12 | 4 |
| `SRgb!double` | 24 | 8 |
| `Oklch!float` | 12 | 4 |
| `Oklch!double` | 24 | 8 |
| `Alpha!(SRgb!float)` | 16 | - |
| `Alpha!(SRgb!double)` | 32 | - |
| `Premultiplied!(LinearSRgb!float)` | 16 | - |

The 32-byte `Alpha!(SRgb!double)` representation is expected:

- color: 24 bytes
- alpha: 8 bytes
- total: 32 bytes

No unexpected padding was observed.

## CTFE

The following succeeded on both compilers:

- construction of typed color values at compile time;
- execution of `@safe pure nothrow @nogc` manipulation functions;
- generation of a compound `Theme` value at compile time;
- initialization of a `static immutable Theme` from the CTFE result;
- compile-time validation through `static assert`.

Example result:

    accent       = Oklch!float(0.68, 0.16, 210)
    accentHover  = Oklch!float(0.72, 0.16, 210)
    accentMuted  = Oklch!float(0.88, 0.16, 210)

## Conclusions

The candidate architecture is viable:

1. color-space identity can be represented in the D type system;
2. this has no observed storage overhead compared with equivalent raw scalar
   structs;
3. `float` and `double` generic color types are practical;
4. an orthogonal `Alpha!Color` wrapper is practical;
5. a distinct premultiplied representation is practical;
6. CTFE can generate complete compound theme values;
7. CTFE does not require abandoning `@safe pure nothrow @nogc`.

## Decisions not yet made

R0.1 does not establish the final public API.

Still open:

- exact naming of alpha wrappers;
- whether `Premultiplied!Color` stores a color object plus alpha or exposes a
  different internal representation;
- construction/range policy;
- component access conventions;
- ABI guarantees;
- GPU-specific packing;
- final aliases;
- conversion API.

## Next experiment

R0.2 will investigate the first real color-space transformation:

    encoded sRGB <-> linear-light sRGB

It will test:

- mathematical correctness;
- extended-range behavior;
- `float` and `double`;
- CTFE;
- DMD/LDC agreement;
- reference vectors;
- round-trip tolerances;
- generated-code characteristics.
