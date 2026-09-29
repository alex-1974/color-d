# Documentation publication

The public GitHub Pages layout is:

```text
/              latest stable documentation
/dev/          current develop / unreleased DDox
/vX.Y.Z/       immutable versioned release documentation
```

Since v0.1.0, the root contains the latest qualified release documentation.
Each release also remains available under its immutable versioned path, while
`/dev/` follows `develop`.

The publication workflows preserve these boundaries:

1. a qualified release tag builds immutable `/vX.Y.Z/` documentation;
2. that qualified release becomes the root/latest-stable documentation;
3. later `develop` publication updates only `/dev/` and reconstructs stable
   documentation from published release artifacts;
4. release/version metadata and documentation remain consistent.

Before any release exists, the same assembly machinery falls back to the
repository landing page and links users to `/dev/`. This remains a tested
bootstrap case rather than the current project state.

GitHub Pages uses **GitHub Actions** as its publishing source. A separate
branch/Jekyll publisher would compete with the DDox deployment and must remain
disabled. The `docs-pages.yml` workflow is the sole Pages publisher for normal
`develop` updates and release publication.
