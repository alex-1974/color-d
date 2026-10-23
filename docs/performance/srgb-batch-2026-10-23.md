# sRGB batch and byte-table measurement

The reusable `SRgb8DecodeTable!T` is intended for consumers that repeatedly
process encoded RGB8 values. It contains the exact scalar decode result for
each of the 256 byte values; it does not interpolate, clip, gamut-map, or
quantize.

The exact scalar batch APIs are `decodeSrgbBatch` and `encodeSrgbBatch`. They
preserve the existing transfer semantics and write only into caller-owned
output storage.

## Local measurement

Command:

```text
dmd-2.113.0 -Isource -of=/tmp/color-d-srgb-decode-batch \
  tests/performance/srgb_decode_batch_probe.d source/color/rgb.d
/tmp/color-d-srgb-decode-batch
```

Workload: 4,096 byte samples repeated 2,000 times, or 8,192,000 scalar
lookups. The corpus cycles through all 256 encoded byte values.

| Path | Time | Checksum |
| --- | ---: | ---: |
| scalar transfer | 2,002 ms | 2.54782e+06 |
| reusable decode table | 50 ms | 2.54782e+06 |

This is a local diagnostic rather than a portable throughput claim. It shows
that table construction can be amortized for repeated RGB8 workloads. The
consumer still owns the choice of table lifetime and must use the exact batch
path when arbitrary floating-point inputs or extended values are required.
