# color-d documentation style

This document is for maintainers. It is repository documentation and is not
part of the consumer package.

The goal is simple: a reader should understand the public color model and
solve a real problem without reading research history or reverse-engineering
tests.

The writing style follows the discipline of clear technical prose: remove
clutter, prefer concrete language, use active verbs, and give the reader
information in the order they need it.

## 1. Write for the reader

Start with the question the caller has.

Prefer:

> Convert encoded sRGB to linear light before compositing.

over:

> The transfer-function implementation provides a transformation facility for
> callers that require a linearized representation.

Use the domain name directly. Say `encoded sRGB`, `linear-light sRGB`,
`Oklab`, `OKLCH`, `alpha`, and `gamut mapping` when those are the concepts
that matter.

Explain why a distinction exists before listing mechanics or edge cases.

## 2. Put information in layers

User documentation should normally proceed from common path to detail:

1. what problem this API solves;
2. the smallest useful example;
3. the semantic distinction that prevents misuse;
4. range, failure, allocation, or precision behavior that changes caller code;
5. links to deeper material.

Do not begin tutorials with compiler defects, benchmark history, research
chronology, or rejected alternatives. Those are evidence for maintainers, not
the normal learning path.

## 3. Keep paragraphs focused

A paragraph should normally make one point. Short paragraphs are easier to
scan in Markdown and DDox.

Prefer verbs over abstract nouns:

- `convert` instead of `perform a conversion`;
- `clip` instead of `apply clipping`;
- `validate` instead of `perform validation`;
- `map into sRGB gamut` instead of `perform gamut-mapping processing`.

## 4. Public Ddoc structure

Every public module needs a short module-level explanation of its role.

A public callable should provide the caller-visible contract needed to use it correctly. A non-trivial public declaration should normally provide:

- one clear summary sentence;
- caller-visible semantics before implementation detail;
- `Params:` when parameter meaning is not obvious from the signature;
- `Returns:` when the result has semantic conditions;
- range/domain or failure behavior when relevant;
- allocation behavior when material;
- standards/provenance when normative;
- `See_Also:` for the most important adjacent operation.

Use custom DDox/Ddoc sections only when they help the reader scan the
contract. Useful section names in color-d include:

```text
Semantics:
Common_Path:
Range:
Failure:
Allocation:
Compile_Time:
Standards:
See_Also:
```

Do not mechanically add every section to every declaration.

## 5. Document the semantic boundary, not the implementation

Ddoc should say what callers can rely on.

Good:

> Extended finite values are preserved. No clipping or gamut mapping is
> performed.

Usually not useful in public Ddoc:

> The implementation enters the scaled fallback after the ordinary matrix
> overflows.

The second statement belongs in code comments, regression tests, an ADR, or
research evidence unless the mechanism itself changes caller-visible
behavior.

## 6. Every public callable has an executable DDox example

Every public function, method, constructor, property, and other callable declaration must have its own documented `unittest` immediately after the declaration it teaches. This is a v0.1.1 documentation contract: examples are part of the public reference, not optional coverage shared implicitly across a callable family.

Use:

```d
///
@safe pure nothrow @nogc unittest
{
    const encoded = SRgbd(0.5, 0.25, 0.0);
    const linear = encoded.toLinear;

    assert(linear.r > linear.g);
}
```

The leading `///` is deliberate. Ddoc/DDox associates the documented
`unittest` with the preceding declaration, while normal test execution
compiles and runs the same code.

Each callable gets its own example even when several overloads or related functions look similar. Keep each example focused enough that this stronger coverage improves the reference instead of turning DDox into a regression-test dump.

A DDox example should:

- teach one idea;
- fit on one screen where practical;
- use meaningful variable names;
- use the public API exactly as a caller would;
- prefer UFCS when that is the intended ergonomic form;
- include a short comment only when it explains a non-obvious semantic step;
- avoid test helpers, random corpora, implementation internals, and tolerance
  machinery unless the tolerance is the lesson.

## 7. Regression tests are not documentation examples

Ordinary `unittest` blocks remain the right place for:

- boundary grids;
- NaN/infinity/subnormal cases;
- compiler canaries;
- randomized deterministic corpora;
- internal reference implementations;
- exact hash checks;
- performance-sensitive regression probes.

Do not prefix those tests with `///` merely to increase example count.

A module with ten public callables therefore has at least ten documented examples: one attached to each callable. The examples may be deliberately small and parallel when the declarations form a family, but each must still show why and how that callable is used.

## 8. Place examples directly after the declaration they document

DDox association is positional.

A documented `unittest` placed after the wrong overload may render as an
example for that overload even if the test calls a different function.

During review, check both:

- does the example compile?
- is it attached to the declaration a reader will expect?

### DDox renderer limitation

The documented unittest remains the source-level documentation contract even
when DDox does not render every example separately. The current DDox/DMD
documentation pipeline can omit examples for some struct members and can
collapse examples in some overload groups.

Do not restructure the public API or duplicate examples merely to work around
that renderer behavior. CI validates stable properties of the generated site,
such as public module pages and local links, while source review verifies the
one-documented-unittest-per-public-callable rule. Treat a future renderer that
restores complete example association as a tooling improvement to re-audit,
not as a reason to weaken the source-level contract.

## 9. Use each documentation form for one job

### README

Answer quickly what color-d is, why its explicit types matter, the common
path, installation/support status, and where to read more.

### Tutorial

Teach a path from start to finish.

### How-to

Solve one task with minimal detour.

### Concept

Explain a model or distinction, such as encoded versus linear light or
extended values.

### DDox reference

State the exact declaration contract and provide compact executable examples.

### Research/evidence

Explain why an implementation or policy was accepted. Research is not a
substitute for user documentation.

## 10. Release documentation must stand alone

Every relative link in the consumer Markdown set must resolve inside the
consumer archive.

Do not link consumer documentation to export-ignored ADRs, research logs,
repository CI files, or maintainer-only documents with relative links.

Links to the public GitHub repository may be absolute when a contributor
needs repository-only material.

## 11. Review checklist

For a public API or documentation PR, ask:

- Can a new user identify the common path without reading research?
- Does the first paragraph say what the operation means?
- Are encoded and linear-light values clearly distinguished where relevant?
- Is hidden clipping, gamut mapping, allocation, or conversion explicitly
  absent when callers could otherwise assume it?
- Are failure and `.init` semantics stated where non-obvious?
- Does every public callable have its own DDox example?
- Is each DDox example attached to the correct declaration?
- Does the example use only public API?
- Is the example smaller than the regression test for the same feature?
- Do all consumer-documentation relative links resolve in the exported package?
- Could any sentence be removed without losing meaning?

If the last answer is yes, remove it.
