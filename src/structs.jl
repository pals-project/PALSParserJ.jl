using Libdl

# Cached path to the PALSParserCpp shared library; empty until first resolved by
# libparser(). A Ref rather than a const String so the path is read at call time
# rather than frozen into the precompile cache, which keeps the cache valid
# across machines and lets the environment variables below take effect without
# a forced recompile.
const LIBPARSER = Ref{String}("")

# Explicit overrides are for local development. Never search a sibling build/
# implicitly: it may be a stale binary or have the wrong CPU architecture.
function _libparser_candidates()
  if haskey(ENV, "PALS_PARSER_CPP_LIB")
    return [abspath(ENV["PALS_PARSER_CPP_LIB"])]
  end
  roots = haskey(ENV, "PALS_PARSER_CPP_DIR") ? [ENV["PALS_PARSER_CPP_DIR"]] : String[]
  names = ("libPALSParserCpp.$(Libdl.dlext)", "PALSParserCpp.$(Libdl.dlext)")
  return [abspath(joinpath(r, "build", s, n))
          for r in roots for s in ("", "Release", "Debug") for n in names]
end

# Import lazily so an explicit developer override can be used without loading
# a second copy of the native library from the artifact. Resolve the global in
# the newest world after the first import (Julia 1.12+ tracks global bindings).
function _jll_libparser_path()
  @eval import PALSParserCpp_jll
  return Base.invokelatest(() -> PALSParserCpp_jll.libPALSParserCpp_path)
end

function _find_libparser()
  candidates = _libparser_candidates()
  if !isempty(candidates)
    for path in candidates
      isfile(path) && return path
    end
    error("Explicit PALS parser override does not exist. Searched:\n" * join(candidates, "\n"))
  end
  return _jll_libparser_path()
end

"""
    PALSParserJ.libparser() -> String

Absolute path to the PALSParserCpp shared library every `@ccall` here targets
(through [`_csym`](@ref)), resolved on first use and cached thereafter. Throws a descriptive error listing
every path tried if the library cannot be found.

Resolution is lazy. Normal installations load the platform-matched library from
PALSParserCpp_jll. Explicit PALS_PARSER_CPP_LIB or PALS_PARSER_CPP_DIR overrides
are available for native development and take precedence over the artifact.
"""
function libparser()
  isempty(LIBPARSER[]) && (LIBPARSER[] = _find_libparser())
  return LIBPARSER[]
end

# Function pointers into the library, looked up on first use.
const _CSYMS = Dict{Symbol,Ptr{Cvoid}}()

"""
    PALSParserJ._csym(name::Symbol) -> Ptr{Cvoid}

The address of the C function `name` in the PALSParserCpp library (see
[`libparser`](@ref)), looked up on first use and cached thereafter.

Every call into the library goes through this pointer, `@ccall \$(_csym(:f))(...)`,
rather than naming the library: Julia 1.13 requires the library in a `ccall` to
be a constant name, and the path here is only known at run time.
"""
function _csym(name::Symbol)
  get!(_CSYMS, name) do
    Libdl.dlsym(Libdl.dlopen(libparser()), name)
  end
end

# ─── constants matching the C header ────────────────────────────────────────
# Sentinel meaning "no node" / "append at the end"; (size_t)-1 in C.
const YAML_NULL_ID = typemax(Csize_t)

# ─── core types ──────────────────────────────────────────────────────────────

"""
    YAMLTree

Owns a C `YAMLTreeHandle`. Freed automatically when the object is GC'd.
Do not use the handle after the tree has been freed.
"""
mutable struct YAMLTree
  handle::Ptr{Cvoid}

  function YAMLTree(handle::Ptr{Cvoid})
    handle == C_NULL && error("Invalid YAML tree handle (C returned NULL)")
    t = new(handle)
    finalizer(t) do tree
      if tree.handle != C_NULL
        @ccall $(_csym(:delete_tree))(tree.handle::Ptr{Cvoid})::Cvoid
        tree.handle = C_NULL
      end
    end
    return t
  end
end

#---------------------------------------------------------------------------------------------------

"""
    YAMLNode

A reference to a single node within a `YAMLTree`.  Holding a `YAMLNode` keeps
its parent tree alive.  Node ids are invalidated if the tree is deleted.
"""
struct YAMLNode
  tree::YAMLTree   # keeps the tree alive
  id::Csize_t      # node id within the tree
end

# Two YAMLNodes are equal when they point at the same id in the same tree.
# Defining these lets YAMLNode be used as a Dict key (e.g. in node_correspondence).
Base.:(==)(a::YAMLNode, b::YAMLNode) = (a.tree === b.tree) && (a.id == b.id)
Base.hash(n::YAMLNode, h::UInt) = hash(n.id, hash(objectid(n.tree), h))

#---------------------------------------------------------------------------------------------------

"""
Whether a problem leaves the expanded trees trustworthy.

- `PROBLEM_ERROR` — the document is wrong here and expansion could not work
  around it. Do not trust the affected part of the trees.
- `PROBLEM_WARNING` — expansion produced a usable result; something was assumed
  or skipped, but the trees are still sound.

Mirrors `enum problem_severity` in PALSParserCpp.h.
"""
@enum ProblemSeverity::Cint PROBLEM_ERROR = 0 PROBLEM_WARNING = 1

"""
Who has to act on a problem.

- `PROBLEM_INPUT` — the document is wrong; the lattice author can fix it.
- `PROBLEM_UNSUPPORTED` — valid PALS that PALSParserCpp does not implement yet.
  Editing the lattice will not clear it.
- `PROBLEM_UNSPECIFIED` — the PALS standard does not define the case, so nothing
  was invented. Neither the author nor the library is in the wrong.

Mirrors `enum problem_origin` in PALSParserCpp.h.
"""
@enum ProblemOrigin::Cint PROBLEM_INPUT = 0 PROBLEM_UNSUPPORTED = 1 PROBLEM_UNSPECIFIED = 2

# Raw C struct mirroring `struct problem` from PALSParserCpp.h. Both strings are
# owned by the C side and are freed with free_lattice_problems; the two enums are
# C `int`s. Layout must match field for field and in order.
struct ProblemC
  message::Cstring
  path::Cstring
  severity::Cint
  origin::Cint
end

# Raw C struct mirroring `struct problem_list`: an owning array of ProblemC and
# its length. Carries the problems found while building the full_expanded tree;
# freed with free_lattice_problems.
struct ProblemListC
  items::Ptr{ProblemC}
  count::Csize_t
end

# Raw C struct returned by parse_and_expand_pals — five tree handles plus the
# problem list, all by value. Layout must match `struct lattices`, field for
# field and in order.
struct LatticesHandle
  original::Ptr{Cvoid}
  combined::Ptr{Cvoid}
  expanded::Ptr{Cvoid}
  full_expanded::Ptr{Cvoid}
  adjunct::Ptr{Cvoid}
  problems::ProblemListC
end

#---------------------------------------------------------------------------------------------------

# Raw C structs for build_correspondence_map. NodeLinkC mirrors `struct
# node_link` and CorrespondenceMapC mirrors `struct correspondence_map` from
# PALSParserCpp.h.
struct NodeLinkC
  original::Csize_t
  combined::Csize_t
  full_expanded::Csize_t
  adjunct::Csize_t
end

struct CorrespondenceMapC
  links::Ptr{NodeLinkC}
  count::Csize_t
end

#---------------------------------------------------------------------------------------------------

# Raw C struct for match_names. Mirrors `struct name_matches` from
# PALSParserCpp.h: a flat array of matched node ids and its length.
struct NameMatchesC
  nodes::Ptr{Csize_t}
  count::Csize_t
end

# Raw C struct for controller_expressions. Mirrors `struct node_list` from
# PALSParserCpp.h: a flat array of node ids and its length.
struct NodeListC
  nodes::Ptr{Csize_t}
  count::Csize_t
end

#---------------------------------------------------------------------------------------------------

# Raw C struct returned by parameter_value. Mirrors `struct param_value`
# from PALSParserCpp.h. `kind` is one of the PARAM_VALUE_* constants below;
# `number` is meaningful when kind is PARAM_VALUE_NUMBER; `string` is an owning C
# string (freed with yaml_free_string) when kind is PARAM_VALUE_STRING, else
# NULL. The Cint/Cdouble/Cstring layout, with padding after `kind`, matches the
# C `int`/`double`/`char*` struct.
struct ParamValueC
  kind::Cint
  number::Cdouble
  string::Cstring
end

# `enum param_value_kind` from PALSParserCpp.h.
const PARAM_VALUE_MISSING = Cint(0)
const PARAM_VALUE_NUMBER = Cint(1)
const PARAM_VALUE_STRING = Cint(2)

#---------------------------------------------------------------------------------------------------

"""
One problem found while reading or expanding a document.

- `message` — human-readable description, always present.
- `path` — the logical spot it was found at, such as `"q1>ApertureP.shape"`.
  Empty when the problem is not tied to one place. This is a location within the
  document, not a file name or a line number; `message` already names the file
  where the file is the point.
- `severity` — a [`ProblemSeverity`](@ref): can the trees still be trusted?
- `origin` — a [`ProblemOrigin`](@ref): whose problem is it?

Only a `PROBLEM_INPUT` can be cleared by editing the lattice, which is what makes
the last field worth reading: a tool that fails on any problem at all will fail
on lattices whose author has nothing left to fix.
"""
struct Problem
  message::String
  path::String
  severity::ProblemSeverity
  origin::ProblemOrigin
end

function Base.show(io::IO, p::Problem)
  print(io, p.severity === PROBLEM_ERROR ? "ERROR" : "WARNING")
  p.origin === PROBLEM_UNSUPPORTED && print(io, " (unsupported)")
  p.origin === PROBLEM_UNSPECIFIED && print(io, " (unspecified by PALS)")
  isempty(p.path) || print(io, " at ", p.path)
  print(io, ": ", p.message)
end

"""
Five representations of a lattice, each as a root `YAMLNode`, plus the list of
problems found while expanding it.

`expanded` and `full_expanded` are the same expanded lattice holding the same
values; `full_expanded` additionally carries every parameter the bookkeeper
computed, while `expanded` keeps only what the author wrote. See
[`parse_and_expand_pals`](@ref) for what each view holds.

`problems` is a `Vector{`[`Problem`](@ref)`}` — one entry per problem
encountered during expansion (undefined lattice, dangling element/line
references, undefined `inherit`/`repeat`/`Fork` targets, misspelled names, and
expressions that could not be evaluated). It is empty when expansion was clean.
Filter it on `severity` or `origin` to decide what is worth acting on:

```julia
lat = parse_and_expand_pals("ex.pals.yaml"; problems = :none)
mine = filter(p -> p.origin === PROBLEM_INPUT, lat.problems)
```
"""
struct Lattices
  original::YAMLNode
  combined::YAMLNode
  expanded::YAMLNode
  full_expanded::YAMLNode
  adjunct::YAMLNode
  problems::Vector{Problem}
end
