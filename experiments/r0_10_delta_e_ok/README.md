# R0.10 — deltaEOK experiment

Research experiment for Oklab Euclidean color difference.

The experiment validates:

- direct `Oklab!T` to `Oklab!T` distance;
- `float` and `double`;
- runtime and CTFE behavior;
- UFCS-compatible use;
- finite extended Oklab values;
- NaN and infinity propagation;
- analytical reference cases;
- generated metric properties;
- floating-point range robustness;
- DMD and LDC debug/release behavior.

Implementation candidates compared by the experiment:

- direct `sqrt(dL*dL + da*da + db*db)`;
- a custom scaled three-dimensional norm;
- raw three-argument Phobos `hypot`;
- guarded three-argument Phobos `hypot`.

The validated preferred research candidate is guarded Phobos `hypot`:

1. any NaN component difference produces NaN;
2. otherwise any infinite component difference produces +Inf;
3. otherwise the finite Euclidean norm is delegated to Phobos `hypot`.

The direct squared-sum candidate is retained in the experiment to demonstrate
its compiler/build-dependent range behavior.

The custom scaled norm is retained as a validated fallback/reference
candidate.

Raw Phobos `hypot` is retained to reproduce its observed special-value
behavior separately from the guarded candidate.

The durable research contract is:

`docs/research/R0_10_DELTA_E_OK.md`

Observed conclusions are recorded in:

`RESULTS.md`

No public API is frozen by this experiment.
