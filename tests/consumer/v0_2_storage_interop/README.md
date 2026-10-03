# v0.2 storage / interop consumer fixture

This project is intentionally a separate DUB package. It validates the public
`import color;` surface from a consumer context rather than as provider-side
module unittests.

It exercises two v0.2.0 consumer-shaped boundaries:

- editor/configuration: exact `#RRGGBBAA` input -> `SRgba8` storage ->
  straight computational sRGB -> explicit linear-light conversion, including a
  CTFE-built fixed token;
- imagery/renderer interchange: raw RGBA bytes -> `SRgba8` -> computational
  sRGB -> checked byte export.

The fixture also proves:

- full-byte hex canonicalization;
- rejection without destination modification;
- straight-alpha hidden RGB preservation;
- explicit failure for out-of-range computational values;
- no theme/renderer/storage policy is imported into color-d;
- consumer helpers remain `@safe pure nothrow @nogc`.

It depends on the repository root through a local path only because this is a
pre-release qualification fixture. Release qualification separately tests a
clean external package consumer.
