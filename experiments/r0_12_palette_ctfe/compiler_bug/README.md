# R0.12 compiler-bug isolation

This directory contains reduced reproductions created while investigating the
R0.12-E 1 × 1 palette runtime failure.

The purpose is to separate:

```text
color mathematics
palette composition
CTFE
generic static-array transport
compiler runtime code generation
```

before allowing a compiler-dependent observation to influence color-d
architecture.

## Environment

The controlled test environment is:

```text
Ubuntu 26.04.1 LTS
x86-64
```

Controlled compilers:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0

LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
```

Both Debug and Release forms were tested.

These are the controlled `~/dlang` installations used by the workspace
toolchain rather than distribution-owned compiler binaries.

## Files

### `repro_min_return.d`

Smallest important standalone reproducer.

It returns a:

```text
struct-of-three-floats [1][1]
```

from a function.

It contains no:

```text
templates
CTFE
color-d dependency
gamut code
external package
```

Observed result:

```text
DMD 2.111.0  FAIL
DMD 2.112.0  FAIL
DMD 2.112.1  FAIL
DMD 2.113.0  FAIL

LDC 1.41.0   PASS
LDC 1.42.0   PASS
LDC 1.43.0   PASS
```

for both Debug and Release.

This is the preferred small upstream reproducer.

### `repro_min_param.d`

Control test for static-array parameter access.

Observed result:

```text
all tested DMD versions PASS
all tested LDC versions PASS
```

Therefore ordinary parameter reading alone is not sufficient to reproduce the
defect.

### `repro_flat.d`

Early reduced palette-shaped reproducer.

It demonstrated corruption when a nested static array is returned.

### `repro_nested_hue.d`

Related early reduction retaining the hue-shaped data.

### `repro_trigger_matrix.d`

Tests multiple static-array dimensions and construction forms.

It established that:

```text
float 1 × 1
```

is a particularly sensitive shape in the tested DMD configuration, while
larger shapes do not reproduce every failure.

It also demonstrated that changing whole-array assignment to element-wise
assignment is not a general workaround.

### `repro_abi_matrix.d`

Observer-free matrix that varies:

```text
return shape
argument count
argument use
scalar type
```

It showed that DMD 2.113.0 fixes several related generic return cases while the
minimal nested-static-array float return remains affected.

The evidence therefore does not support treating the problem as one single
simple trigger.

### `repro_return_compat.d`

Tests non-generic compatibility forms.

For the tested DMD versions:

```text
naked by-value return    FAIL
out destination          PASS
ref destination          PASS
simple struct wrapper    PASS
```

LDC passes all variants.

This result is useful but is not sufficient to choose the final color-d
workaround because the generic cases behave differently.

### `repro_boxed_generic.d`

Tests a generic boxed return and a generic bundle return.

Observed:

```text
DMD 2.111.0–2.112.1:
    generic boxed/bundle runtime results are not reliable

DMD 2.113.0:
    tested boxed/bundle forms PASS

LDC 1.41.0–1.43.0:
    PASS
```

The corresponding CTFE static assertions compile successfully.

Therefore a simple generic wrapper is not a sufficient baseline workaround.

### `repro_generic_into.d`

Tests:

```text
ref output
+
by-value static-array inputs
```

Observed:

```text
DMD 2.111.0  SIGSEGV / exit 139
DMD 2.112.0  SIGSEGV / exit 139
DMD 2.112.1  SIGSEGV / exit 139

DMD 2.113.0  PASS

LDC 1.41.0   PASS
LDC 1.42.0   PASS
LDC 1.43.0   PASS
```

Therefore changing only the output transport is not sufficient for the older
DMD baseline.

### `repro_generic_ref_inputs.d`

Tests the common compatibility form eventually selected by the experiment:

```text
output:
    ref

static-array inputs:
    ref const
```

Observed:

```text
DMD 2.111.0  PASS
DMD 2.112.0  PASS
DMD 2.112.1  PASS
DMD 2.113.0  PASS

LDC 1.41.0   PASS
LDC 1.42.0   PASS
LDC 1.43.0   PASS
```

for:

```text
Debug
Release
float
double
```

This is the transport form used by the final R0.12-E runtime experiment.

## Interpretation

The observed problem is a compiler/runtime code-generation or calling-boundary
issue associated with specific static-array transport forms.

The evidence does not establish the exact internal DMD backend root cause.

Do not describe it more narrowly than the reproductions support.

In particular, the evidence does not establish that:

```text
all static arrays are broken
all nested arrays are broken
all struct returns are broken
all generic returns are broken
CTFE is broken
```

Those statements would contradict the observed control cases.

## color-d consequence

The R0.12 experiment preserves the compiler baseline without a version-specific
branch by using:

```text
ref output
+
ref const static-array inputs
```

for the runtime integration path.

The value-returning helpers remain useful research/CTFE wrappers but are not
established as a generally safe production runtime ABI for the full baseline.

No compiler switch is required for correctness by the current implementation.

Compiler switches remain a valid future option when independently justified by:

```text
a reproduced correctness problem
or
measured material performance
```

## Upstream status

The reduced DMD issue has not yet been filed from this directory.

Previous repository searches did not identify an exact existing issue matching
the minimal runtime corruption reproducer.

When filing upstream, prefer `repro_min_return.d` and report observed behavior
without asserting an unverified backend root cause.
