# Error and validation model

`color-d` is a mathematical library, so it separates three kinds of state.

## Mathematical extended values

NaN, infinity, negative components, components above one, raw hue, and raw
chroma are not globally converted into exceptions or silently repaired.
Individual operations define their own domain and propagation behavior.

## Programmer preconditions

Some low-level construction operations require properties that callers are
expected to satisfy. For example, `linearSchedule!N` requires finite
endpoints. Such requirements may be enforced with assertions and are not a
recoverable user-input channel.

## Recoverable validation

When an operation intentionally validates runtime input, success is explicit.

`Wcag2Measurement!T`
: `.valid` is the success channel. Invalid standards-domain input yields an
invalid measurement whose stored scalar is NaN.

`tryTonesAtLightnessAndChromaInto`
: returns `false` when slice lengths differ and performs no output writes.

Callers should not infer success from an output value when the API provides an
explicit success channel.

The library does not arbitrarily mix exceptions, null, sentinel integers, and
Boolean status for equivalent failures.
