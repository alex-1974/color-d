# Toolchain canaries

This directory contains minimal production CI probes for toolchain behavior
that still affects the supported color-d implementation.

The sources are kept small so they can be compiled independently from the
library. Historical reductions, control matrices, and investigation notes
remain research evidence and are not duplicated here.

## TC-0001

`tc0001_static_array_return_canary.d` is an exact source copy of the smallest
validated DMD reproducer for TC-0001: a by-value return of a nested static array
whose element is a three-`float` struct.

DMD 2.113.0 still reproduced the wrong-code result on the validated Linux
x86-64 matrix when this canary was promoted. LDC 1.41.0–1.43.0 passed the
historical matrix.

Fast CI treats exit status 1 as the known reproduced defect and status 0 as a
signal to re-evaluate the production workaround. Any other exit status is a CI
failure.

The research copy is intentionally retained until the external research
migration tracked by issue #107 has been independently verified.
