# R0.13 — Operation × property × comparison matrix

**Status:** VALIDATED
**Parent:** R0.13
**Document revision:** 0.5
**Date:** 2026-09-25
**GitHub:** #9

This matrix converts the R0.2–R0.12 inventory into explicit R0.13 work items.
R0.13-A established the comparison taxonomy; validated R0.13-B findings are
now promoted into the B rows without freezing production thresholds.

Legend:

```text
EXACT       exact equality / exact semantic result
CLASSIFY    strict classification
REFERENCE   independent or authoritative numerical reference
DERIVED     round-trip / derived numerical property
CROSS       runtime/CTFE/compiler characterization
POLICY      explicit caller/specification semantic threshold
ALGORITHM   algorithm-internal convergence/execution threshold
```

No approximate threshold in this matrix is frozen.

| Operation | Property | Class | Reference | Scalar | R0.13 action |
|---|---|---|---|---|---|
| sRGB decode | zero endpoint | EXACT candidate | IEC / ICC | float,double | B: exact zero observed; F: promote only if semantic contract remains exact |
| sRGB encode | zero endpoint | EXACT candidate | IEC / ICC | float,double | B: exact zero observed; F: promote only if semantic contract remains exact |
| sRGB transfer | branch boundary | REFERENCE / CLASSIFY | IEC | float,double | B: rounded-threshold discontinuity characterized; keep targeted |
| sRGB transfer | ordinary values | REFERENCE | IEC + pinned CSS samples | float,double | B: scalar-specific reference error characterized |
| sRGB transfer | extended finite values | REFERENCE | formula-derived | float,double | B: scalar-specific reference error characterized |
| sRGB transfer | encode/decode round trip | DERIVED | self + independent formula | float,double | B: derived envelope characterized; branch boundary remains separate |
| linear sRGB→XYZ | black→zero | EXACT candidate | matrix algebra | float,double | B: exact black observed; F: promote only if semantic contract remains exact |
| linear sRGB↔XYZ | primaries / white | REFERENCE | IEC colorimetry | float,double | B: characterized against independent derivation |
| linear sRGB↔XYZ | ordinary values | REFERENCE | pinned CSS rational matrix + independent derivation | float,double | B: characterized; derivation agrees pinned coefficient set |
| linear sRGB↔XYZ | round trip | DERIVED | pinned CSS rational matrix + independent derivation | float,double | B: derived envelope characterized separately |
| XYZ↔Oklab | black→zero | EXACT candidate | Oklab primary | float,double | B: exact black observed in harness; F: promote only if semantic contract remains exact |
| XYZ↔Oklab | ordinary values | REFERENCE | primary + pinned CSS route | float,double | B: CSS-route reference characterized; Ottosson direct route is comparator only |
| XYZ↔Oklab | extended finite values | REFERENCE | pinned CSS route + primary route comparator | float,double | B: same-route reference characterized; route discrepancy kept separate |
| XYZ↔Oklab | round trip | DERIVED | pinned CSS route | float,double | B: derived envelope characterized separately |
| Oklab↔OkLCh | exact C==0 achromaticity | EXACT / CLASSIFY | color-d semantics | float,double | C: preserve |
| Oklab↔OkLCh | near-achromatic decision | POLICY | caller policy | float,double | C: keep explicit |
| CSS OkLCh conversion | powerless hue C<=0.000004 | POLICY | CSS Color 4 2026-09-13 | n/a | A/C: external semantic example only |
| Oklab↔OkLCh | Cartesian/polar round trip | DERIVED | analytical/independent | float,double | C: characterize |
| hue handling | ±180 tie / path selection | EXACT | CSS + color-d semantics | float,double | C: preserve |
| hue arithmetic | angular result | DERIVED | analytical angle reference | float,double | C: design angular comparator |
| premultiply | alpha 0/1 identities | EXACT candidate | compositing algebra | float,double | C: verify |
| unpremultiply | defined round trip | DERIVED | compositing algebra | float,double | C: characterize |
| source-over | identity cases | EXACT candidate | W3C compositing | float,double | C: verify |
| source-over | general vectors | REFERENCE | W3C formula | float,double | C: characterize |
| source-over | associativity observation | DERIVED | independent route | float,double | C: characterize, not exact |
| interpolation | exact endpoints | EXACT | interpolation semantics | float,double | C: preserve |
| interpolation | exact hue policy/ties | EXACT | CSS / color-d policy | float,double | C: preserve |
| interpolation | interior values | DERIVED | analytical/independent | float,double | C: characterize |
| strict inGamut | finite + [0,1] membership | CLASSIFY | color-d geometry | float,double | D: preserve strict |
| epsilon gamut query | expanded boundary | POLICY | caller policy | float,double | D: keep separate |
| clip | selected boundary/idempotence | EXACT candidate | clamp semantics | float,double | D: verify |
| Local MINDE | convergence thresholds | ALGORITHM | pinned CSS algorithm | float,double | D: document separately |
| Ray Trace | ray epsilon / fixed work budget | ALGORITHM | pinned CSS algorithm | float,double | D: scalar-specific ray epsilon and four-intersection budget characterized |
| gamut mapping | status / iterations | EXACT / CROSS | algorithm semantics | float,double | D: exact within one execution where specified, but not scalar/compiler invariant; E: characterize cross execution |
| gamut mapping | mapped coordinates | REFERENCE / DERIVED | reference algorithm | float,double | D: algorithm-specific coordinates and derived idempotence characterized; no cross-method equality assumption |
| WCAG luminance | valid/invalid domain | CLASSIFY | WCAG 2.2 | float,double | C: preserve |
| WCAG luminance | branch boundary | REFERENCE / CLASSIFY | WCAG 2.2 | float,double | C: boundary probes |
| WCAG luminance | numerical value | REFERENCE | WCAG 2.2 | float,double | C: characterize |
| contrast ratio | same-color identity | EXACT candidate | WCAG formula | float,double | C: verify |
| contrast ratio | general values | REFERENCE | independent WCAG route | float,double | C: characterize |
| deltaEOK | x,x == 0 | EXACT | Euclidean identity | float,double | C: preserve |
| deltaEOK | analytical cases | EXACT where representable | analytical | float,double | C: verify |
| deltaEOK | general values | REFERENCE | independent real route | float,double | C: characterize |
| deltaEOK | ULP behavior | diagnostic candidate | independent real route | float,double | C: evaluate usefulness |
| raw tone/palette | copied components | EXACT | structural semantics | float,double | A/F: preserve |
| raw tone/palette | cardinality/endpoints | EXACT | structural semantics | float,double | A/F: preserve |
| palette runtime↔CTFE | raw values | EXACT | CROSS_EXECUTION | float,double | E: verify |
| Ray Trace runtime↔CTFE | success/iterations | CROSS | CROSS_EXECUTION | float,double | E: characterize; D3 already shows compiler-sensitive success metadata for a fixed float probe |
| mapped runtime↔CTFE | components | CROSS | CROSS_EXECUTION | float,double | E: characterize |
| encoded runtime↔CTFE | components | CROSS | CROSS_EXECUTION | float,double | E: characterize |
| compiler↔compiler | post-transform components | CROSS | CROSS_EXECUTION | float,double | E: characterize |
| Debug↔Release | post-transform components | CROSS | CROSS_EXECUTION | float,double | E: characterize |
| CSS cross-space color equivalence | Oklab components ε=0.00001 | POLICY | CSS Color 4 2026-09-13 | CSS semantics | A/C: do not globalize |
| CSS same-space color equivalence | implementation-defined ε | POLICY | CSS Color 4 2026-09-13 | CSS semantics | A/C: do not infer portable bound |


---

# R0.13-B promotion notes

The B characterization adds the following constraints to the matrix:

```text
no universal epsilon
no universal ULP budget
direct-reference envelope != round-trip envelope
near-zero comparison != ordinary relative/ULP comparison
transfer-boundary discontinuity != ordinary floating-point drift
coefficient-route discrepancy != same-route implementation error
```

For B3 specifically, the direct 2021 Ottosson linear-sRGB → Oklab route is
retained as primary-source provenance and route-consistency evidence. It is not
an acceptance oracle for the production linear-sRGB → XYZ → Oklab route using
the pinned CSS/XYZ coefficient path.

The current DMD and LDC runtime outputs were identical on the tested x86_64 Linux
setup. Full runtime ↔ CTFE, Debug ↔ Release and compiler-version portability
claims remain R0.13-E work.

No B observation is promoted here into a production tolerance constant.

---

# R0.13-D promotion notes

D1-D3 add the following constraints:

```text
strict gamut geometry != tolerant boundary policy
algorithm epsilon != comparison tolerance
fixed iteration budget != exact iteration count
mapping success metadata != mapped-color validity
per-execution metadata != cross-scalar/cross-compiler invariant
```

D2 observed Local MINDE iteration-count differences between `float` and
`double` for the same conceptual inputs while both scalar paths remained
successful and in gamut.

D3 observed a stronger distinction for Ray Trace: a fixed `float` OKLCH probe
returned `success=false` under DMD 2.111 and `success=true` under LDC 1.41,
while both returned the same final mapped `float` RGB components and both
remained in gamut. The divergence arose from compiler-dependent intermediate
rounding around the scalar-specific Ray Trace interior/epsilon decisions.

Therefore R0.13-E must not begin from an assumption that Ray Trace diagnostic
metadata is bit- or value-identical across execution environments.


D4 further established that alpha preservation is exact structural semantics,
while complete mapping idempotence after `mapped RGB -> OKLCH -> mapping` is
derived numerical behavior. Local MINDE required zero second-pass iterations in
the sampled set; Ray Trace frequently re-entered its mapping path and the count
was compiler-sensitive, while every second result remained strict in-gamut.

D4 also observed no bit-identical Local MINDE / Ray Trace result pairs across
4096 common out-of-gamut cases, with maximum cross-method deltaEOK around
`0.08`. This is expected algorithm-policy divergence, not a numerical error
envelope.

# Matrix conclusions

The matrix confirms that at least seven concepts must remain distinct:

```text
exact semantic equality
strict classification
reference comparison
derived numerical comparison
cross-execution comparison
explicit semantic/policy threshold
algorithm-internal threshold
```

The newly reviewed CSS Color 4 evidence is particularly important:

```text
CSS itself uses more than one epsilon semantics.
```

Therefore the existence of a standards-defined epsilon is not evidence for a
generic `color-d` epsilon.

It is evidence that a threshold must be named and scoped by the question it
answers.

No production comparison helper is justified by this matrix alone.
