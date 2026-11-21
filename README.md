# PALSParserJ

Julia Interface for Particle Accelerator Language Standard (PALS) files.

## Introduction

`PALSParserJ` is a parser for the Particle Accelerator Language Standard
([PALS](https://github.com/pals-project/pals)) for the Julia language.

In addition, `PALSParserJ` provides translation functions:

- From `PALS` files to [`Bmad`](https://github.com/bmad-sim/bmad-ecosystem) lattice files.
- From `PALS` files to [`SciBmad`](https://github.com/bmad-sim/SciBmad.jl) lattice files.
- From `PALS` files to [`MAD-X`](https://mad.web.cern.ch/mad/) lattice files.

For a Python interface, and a translator from `PALS` to
[`Xsuite`](https://github.com/xsuite/xsuite), use
[PALSParserPy](https://github.com/pals-project/PALSParserPy).

For a translator from `Bmad` to `PALS`, the `Bmad` based `Tao` program can be used.
A translator from `SciBmad` to `PALS` is planned.

## Status

- 2026-02-24: In initial development.
- 2026-07-12: Basic lattice translation done.

## Installation

This branch requires Julia 1.10 or later and uses `PALSParserCpp_jll` to load
platform-matched binaries of
[PALSParserCpp](https://github.com/pals-project/PALSParserCpp). A separate C++
checkout or compiler is not required when using the JLL binaries.

**Packaging preview:** `PALSParserCpp_jll` is not yet registered or published as a
release. Running `Pkg.instantiate()` alone on this branch therefore does not
complete installation. For now, install the generated wrapper and binaries from
a successful [JLL build workflow](https://github.com/pals-project/PALSParserJ.jl/actions/workflows/jll-build.yml)
run, as CI does. These artifacts cover Linux x86_64 (glibc), macOS Apple Silicon
and Intel, and Windows x86_64.

### Install the CI artifacts

The following commands use the [GitHub CLI](https://cli.github.com/) (`gh`),
authenticated with `gh auth login`. Replace `RUN_ID` with the ID of a successful
run that contains both `binary-products` and `generated-wrapper` artifacts.
Artifacts expire according to GitHub's retention policy.

```console
git clone --branch feat/jll-packaging https://github.com/pals-project/PALSParserJ.jl.git
cd PALSParserJ.jl

gh run download RUN_ID --repo pals-project/PALSParserJ.jl --name binary-products --dir products
gh run download RUN_ID --repo pals-project/PALSParserJ.jl --name generated-wrapper --dir generated-jll
```

Start Julia with `julia --project=.` from this checkout and run:

```julia
# Verify and install the native artifact, then check the generated JLL's C API.
# Both downloads must come from the same workflow run.
ENV["JLL_RECIPE"] = "PALSParserCpp"
append!(ARGS, ["products", "generated-jll"])
include("contrib/jll/smoke_tarball.jl")

# The smoke script activates a temporary environment; return to this checkout.
using Pkg
Pkg.activate(".")
Pkg.develop(path="generated-jll")
Pkg.instantiate()
import PALSParserJ
```

Keep `generated-jll` at that location: the local environment references it by
path. The smoke script installs the verified native binary into Julia's artifact
store, so no manual unpacking or library-path configuration is needed. See
[JLL packaging details](contrib/jll/README.md) for the build workflow.

### Optional native development override

To test a locally compiled PALSParserCpp library instead of the JLL binary, set
`PALS_PARSER_CPP_LIB` to the shared library's absolute path **before the first
parser call** in a fresh Julia session:

```julia
ENV["PALS_PARSER_CPP_LIB"] = "/absolute/path/to/libPALSParserCpp.dylib" # macOS
import PALSParserJ
```

Use the corresponding `.so` or `.dll` path on Linux or Windows. Alternatively,
set `PALS_PARSER_CPP_DIR` to the PALSParserCpp checkout; the loader searches its
`build`, `build/Release`, and `build/Debug` directories. The library must match
your Julia process's CPU architecture. Sibling checkouts are no longer discovered
automatically. These overrides select the native library at runtime; they do not
remove the `PALSParserCpp_jll` package dependency from the Julia environment.

## Quick start

From the checkout, in Julia started with `julia --project=.`:

```julia
import PALSParserJ as pj

lat = pj.parse_and_expand_pals("lattice_files/ex.pals.yaml")
println(pj.to_yaml_string(lat.full_expanded))     # the expanded lattice, as YAML

pj.parameter_value(lat, "Q1a>length")             # one parameter's value
pj.match_names(lat.full_expanded, "DH.*>BendP.e1")   # the nodes a name selects

pj.write_bmad_file(pj.pals_to_bmad(pj.parse_file("lattice_files/bta.pals.yaml")),
                   "bta.bmad")
```

## Examples

For usage examples, see the runnable scripts in the `examples` directory, e.g.

```console
julia --project=. examples/read_pals.jl
```

### Jupyter notebooks (IJulia)

Some examples are also provided as Jupyter notebooks (e.g.
`examples/manipulate_tree.ipynb`). To run them you need
[IJulia](https://github.com/JuliaLang/IJulia.jl), the Julia kernel for Jupyter.

Install IJulia once:

```console
julia -e 'using Pkg; Pkg.add("IJulia")'
```

Then launch Jupyter directly from Julia — IJulia bundles its own Jupyter, so no
separate system install is needed (the first launch will offer to install it):

```julia
using IJulia
notebook(dir="examples")
```

This opens Jupyter in your browser; from there open `manipulate_tree.ipynb`.

If you prefer a system-wide `jupyter` command instead, install it with
`pip install jupyter`; adding IJulia as above then registers the Julia kernel
with it, and you can run:

```console
jupyter notebook examples/manipulate_tree.ipynb
```

## Tests

```console
julia --project=. -e 'using Pkg; Pkg.test()'
```

Complete the installation above before running the tests. A manual C++ build
is only needed when using a native development override.
