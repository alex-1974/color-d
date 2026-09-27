# Documentation publication

The public GitHub Pages layout follows the workspace documentation trust model:

```text
/              latest stable documentation
/dev/          current develop / unreleased DDox
/vX.Y.Z/       immutable versioned release documentation
```

Before the first public release, the root page is a landing page that explicitly
states that no stable release has been published. It links to `/dev/`.

The `develop` workflow updates only the development documentation model. The
first release workflow in #14 must extend publication so that:

1. the release tag builds immutable `/vX.Y.Z/` documentation;
2. the same qualified release becomes the root/latest-stable documentation;
3. later `develop` publication does not redefine a released version;
4. release/version metadata and documentation remain consistent.

GitHub Pages is configured to use **GitHub Actions** as its publishing source.
A separate branch/Jekyll Pages publisher would compete with the DDox deployment
and must remain disabled. This repository setting is verified by observing a
normal `develop` push: only the explicit documentation workflow should publish
Pages.
