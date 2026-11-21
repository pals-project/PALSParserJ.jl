# Bundled JLL packaging

The package includes the generated wrapper in `contrib/PALSParserCpp_jll` and
four tested binary tarballs in `products`, copied without recompilation from
[successful run 44931883659](https://github.com/pals-project/PALSParserJ.jl/actions/runs/44931883659).
The wrapper pins download URLs to the binary commit and retains the original
SHA-256 and artifact tree hashes. APC is bundled; no separate APC JLL is needed.
`products/PALSParserCpp-corresponding-source.tar.gz` preserves corresponding source.
Follow the root README to install with Julia's package manager; GitHub CLI and
expiring workflow artifacts are not required.

The regular test workflow tests the bundled wrapper on all four platforms.
The separate, manually runnable `jll-build.yml` workflow remains available to
rebuild and audit native binaries when native source changes. A new build does
not silently replace the committed wrapper or tarballs; update them together
after verifying the new build. No standalone JLL release is published here.

The build recipe pins PALSParserCpp, rapidyaml, PCRE2 and APC source commits.
GitHub Actions builds four native targets, preserves dependency notices, generates
complete corresponding source, and imports the generated JLL on Linux, ARM/Intel
macOS and Windows. Each smoke job then runs PALSParserJ's tests against that local
JLL. New build outputs remain CI artifacts until explicitly promoted into the repository.
The wrapper's new JLL dependency is supplied by `Pkg.develop(path="generated-jll")`
in CI, so no nonexistent public JLL release is needed to bootstrap the branch.

Run the reusable workflow `.github/workflows/jll-build.yml` manually. Source and binary build
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
