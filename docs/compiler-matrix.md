# Compiler matrix

color-d treats DMD and LDC as separate compiler families. Exact versions matter
for compatibility evidence and for compiler-specific workarounds.

## Supported release matrix

The v0.2.0 release is qualified against:

| Frontend generation | DMD | LDC |
| --- | --- | --- |
| 2.112 | 2.112.1 | 1.42.0 |
| 2.113 | 2.113.0 | 1.43.0 |

DMD 2.112.0 is retained as a diagnostic point when a result differs inside the
2.112 line. DMD 2.111.0 and LDC 1.41.0 are retained as legacy diagnostic
canaries: their Phobos `cbrt` is not `pure`, so they cannot satisfy color-d's
public `pure` contract for Oklab conversion. These diagnostic versions are not
supported release compilers.

The normal Fast CI intentionally uses only the current supported pair,
DMD 2.113.0 and LDC 1.43.0. The broader matrix is a scheduled and manually
runnable compatibility gate so daily development does not pay full release
qualification cost.

Promotion to `main` must qualify the supported matrix. A rolling canary also
tests the latest stable DMD and LDC so a new compiler can be evaluated before
the supported matrix is deliberately advanced.

## Reproducible local comparisons

Workspace-controlled installations may live side by side under `~/dlang`.
For controlled experiments and benchmarks, select the compiler explicitly and
keep DUB fixed when DUB itself is not under test. Do not rely on activation
scripts that also mutate PATH or library environment variables.

The workspace baseline command names are:

```text
dmd-2.111.0
dmd-2.112.0
dmd-2.112.1
dmd-2.113.0

ldc-1.41.0
ldc-1.42.0
ldc-1.43.0

dub-dlang-baseline
```

`dub-dlang-baseline` denotes DUB 1.40.0 from the controlled DMD 2.111.0
installation. Distribution-owned bare `dmd`, `ldc2`, and `dub` are not
reference commands for compiler-comparison evidence.

## Compiler-specific evidence

A compiler-specific optimization or workaround requires a reproduced or
measured reason. Record exact compiler versions and, for LDC performance work,
the frontend and LLVM backend where relevant.

Current color-d evidence includes:

- TC-0001: DMD 2.111.0, 2.112.0, 2.112.1, and 2.113.0 reproduce a nested
  static-array return wrong-code defect; LDC 1.41.0–1.43.0 do not.
- TC-0002: the related DMD crash affects 2.111.0–2.112.1 and is fixed in
  DMD 2.113.0.
- TC-0006: the LDC sRGB/WCAG hot-path optimization is backend-specific and
  remains guarded by `version (LDC)` with a portable fallback.

The canonical workspace defect register is `.workspace/TOOLCHAIN_ISSUES.md`.
Repository canaries and tests retain only the production evidence needed to
guard color-d itself.
