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

PALSParserJ is a thin Julia wrapper around the C library built by
[PALSParserCpp](https://github.com/pals-project/PALSParserCpp), so both
repositories must be cloned side by side and the C library must be built first:

```console
git clone https://github.com/pals-project/PALSParserCpp.git
git clone https://github.com/pals-project/PALSParserJ.jl.git

cd PALSParserCpp && cmake -S . -B build && cmake --build build && cd ..

cd PALSParserJ.jl && julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

If PALSParserCpp lives somewhere other than beside this checkout, point at it
with `PALS_PARSER_CPP_DIR` or `PALS_PARSER_CPP_LIB`.

**See the [Installation guide](https://pals-project.github.io/PALSParserJ.jl/guide/installation.html)
for full step-by-step instructions.**

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

The C library must be built first.
