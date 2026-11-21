# JLL packaging preparation

This branch contains PALSParserCpp JLL packaging within the PALSParserJ repository.
No separate JLL repository or binary release is created by its workflows.

The build recipe pins PALSParserCpp, rapidyaml, PCRE2 and APC source commits.
GitHub Actions builds four native targets, preserves dependency notices, generates
complete corresponding source, and imports the generated JLL on Linux, ARM/Intel
macOS and Windows. Each smoke job then runs PALSParserJ's tests against that local
JLL. The generated package and binaries are CI artifacts, not published releases.
The wrapper's new JLL dependency is supplied by `Pkg.develop(path="generated-jll")`
in CI, so no nonexistent public JLL release is needed to bootstrap the branch.

Run the reusable workflow `.github/workflows/jll-build.yml` manually, or push
changes to this branch to run it through `test.yaml`. Source and binary build
products are uploaded as workflow artifacts for review. These are temporary CI
artifacts subject to GitHub retention policies, not permanent distribution URLs.

`prepare_release.jl` is retained as an unpublished preparation helper. No workflow
invokes it; it does not itself create repositories, push commits or publish releases.
Its path layout is intended for a future standalone JLL repository.

Upstream PALSParserCpp is left unchanged and has no declared license. Packaging
notices preserve that status, distinguish the Julia wrapper from native-code
licensing, and retain the native dependencies' notices. See `bundled/notices/NOTICE.txt`.
No legal determination or upstream relicensing is claimed by this branch.

Native preparation already passed 337 C++ tests and 326 core parser/loader checks
on Julia 1.10 and 1.12. Cross-platform BinaryBuilder and artifact-backed wrapper
checks require the GitHub Actions run; those results are separate.
