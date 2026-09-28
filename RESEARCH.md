# color-d research and evidence

Detailed research, experiments, compiler reproducers, benchmark evidence,
historical closeouts, and research-derived specifications live in the companion
repository:

https://github.com/alex-1974/color-d-research

The initial split preserved the research corpus from:

- source repository: `alex-1974/color-d`;
- source commit: `f5ff3dab97c65e6f45e4c0ed192c3143a946c6bc`;
- exact research snapshot commit:
  `5296ffb16d1a619b658c1296f9d8bd0d1d597c83`;
- files: 132;
- bytes: 1,577,331.

Source and destination were verified by path, file mode, byte size, Git blob
identity, and an independent SHA-256 manifest before the duplicate research
paths were removed from the production repository.

The production contract remains in `color-d`:

- public source and Ddoc;
- user documentation;
- production tests and compatibility/toolchain gates;
- accepted compact ADRs;
- CI/release engineering;
- active maintainer/release policy.

Research does not become public API merely because an experiment exists.
Promotion into production still requires an explicit production change with the
appropriate source/API, tests, maintained documentation, and review gates.

The split intentionally did not rewrite historical `color-d` Git history.
Older commits therefore continue to contain the original research material,
while current production tags and normal DUB downloads remain lean.
