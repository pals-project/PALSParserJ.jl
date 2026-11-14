# Helpers the translators share: name and parameter patterns, PALS name/value lists, facility
# lookup, the derived-value folding every target needs, and the multipole representations.
#
# Everything here is target-agnostic. A helper used by one translator alone belongs in that
# translator's file; this file is what more than one of them needs, so that toMadx.jl and
# toSciBmad.jl do not have to reach into toBmad.jl for it.

# A plain identifier: what every target format accepts as a bare name, and so what a translated
# element, attribute or variable name has to look like.
const _NAME_RE = r"^[A-Za-z_][A-Za-z0-9_]*$"

# A PALS path naming one multipole component, as `MagneticMultipoleP.Kn1L`. The captures are:
# K or B (normalized or field), n or s (normal or skew), the multipole order, and a trailing L
# when the component is length integrated.
const _MULTIPOLE_RE = r"^MagneticMultipoleP\.([KB])([ns])([0-9]+)(L?)$"

#---------------------------------------------------------------------------------------------------
"""
    _name_value_pairs(node::YAMLNode)

Return a PALS name/value list as `name => value-text` pairs, in definition order.

Accepts both forms the standard allows for such a list: a map (`vv: 0.3`) and a sequence of
single-key maps (`- vv: 0.3`). An entry written with no value takes PALS' default of zero, and
one whose value is a structure rather than a single value is skipped.
"""
function _name_value_pairs(node::YAMLNode)
  pairs = Pair{String,String}[]
  function add!(child)
    (is_map(child) || is_sequence(child)) && return
    push!(pairs, node_key(child) => _value_text(child))
  end
  if is_map(node)
    for key in keys(node)
      add!(node[key])
    end
  elseif is_sequence(node)
    for entry in node, i in eachindex(entry)
      add!(entry[i])
    end
  end
  return pairs
end

#---------------------------------------------------------------------------------------------------
"""
    _value_text(node::YAMLNode)

Return the text of a value `node`, with a value left unwritten taken as PALS' default of zero.
"""
function _value_text(node::YAMLNode)
  text = strip(String(node))
  return text in ("", "~", "null") ? "0" : String(text)
end

#---------------------------------------------------------------------------------------------------
"""
    _ctrl_variables(props::YAMLNode)

Return a controller's `variables` as `name => value-text` pairs, in definition order.
"""
function _ctrl_variables(props::YAMLNode)
  haskey(props, "variables") || return Pair{String,String}[]
  return _name_value_pairs(props["variables"])
end

#---------------------------------------------------------------------------------------------------
"""
    _facility_entry(facility::YAMLNode, name::String)

Return the `facility` entry named `name`, or `nothing` if there is none. The entry is the
single-key map the translators take as an element; [`_facility_props`](@ref) gives its
properties.
"""
function _facility_entry(facility::YAMLNode, name::String)
  for ele in facility
    node_key(ele[1]) == name && return ele
  end
  return nothing
end

#---------------------------------------------------------------------------------------------------
"""
    _facility_props(facility::YAMLNode, name::String)

Return the property map of the `facility` entry named `name`, or `nothing` if there is none.
"""
function _facility_props(facility::YAMLNode, name::String)
  ele = _facility_entry(facility, name)
  return ele === nothing ? nothing : ele[1]
end

#---------------------------------------------------------------------------------------------------
"""
    _fold(text::AbstractString, f, args::AbstractString...)

Return `text`, or the number it comes to when every one of `args` is a number.

A PALS parameter may be written as an expression, which only the target program can evaluate,
or as a plain number, which the translation can work with. Where a target value has to be
derived from several PALS ones, `text` is that derivation written as a target expression and
`f` is the same derivation as a function, applied here when all of its inputs parse.
"""
function _fold(text::AbstractString, f, args::AbstractString...)
  values = [tryparse(Float64, strip(a)) for a in args]
  any(isnothing, values) && return String(text)
  result = f(values...)
  return isfinite(result) ? string(result) : String(text)
end

#---------------------------------------------------------------------------------------------------
"""
    _times(a::AbstractString, b::AbstractString)

Return the product of two target values, without the clutter of a factor of one.

Two numbers are multiplied out here; a unit factor -- which is what an element of unit length
gives, and what several of the bend derivations reduce to -- comes back as the other operand
alone rather than as a product with nothing in it.
"""
function _times(a::AbstractString, b::AbstractString)
  va, vb = tryparse(Float64, strip(a)), tryparse(Float64, strip(b))
  va !== nothing && vb !== nothing && return string(va * vb)
  va == 1 && return String(b)
  vb == 1 && return String(a)
  return "($a) * ($b)"
end

#---------------------------------------------------------------------------------------------------
"""
    MultipoleRepresentation

Abstract supertype for the multipole representations used during translation.

Concrete subtypes are [`FullRepresentation`](@ref) (the raw, over-parametrized form read
from PALS-YAML) and [`ABRepresentation`](@ref) (the element-specific A/B field integrals).
"""
abstract type MultipoleRepresentation end

#---------------------------------------------------------------------------------------------------
"""
    FullRepresentation <: MultipoleRepresentation

Raw, over-parametrized multipole form filled directly from PALS-YAML.

Holds, keyed by multipole order, whether each coefficient is `normalized` (K vs. B) and
`integrated` (field integral vs. field strength), its `magnitude` (normal/skew pair), and its
`tilt`, together with the element length `L`. It is down-converted to whichever
element-specific representation the element kind requires.

    FullRepresentation()

Construct an empty representation with unit length `L`.
"""
mutable struct FullRepresentation <: MultipoleRepresentation
  normalized::Dict{Int,Bool}
  integrated::Dict{Int,Bool}
  magnitude ::Dict{Int,Vector{Float64}}
  tilt      ::Dict{Int,Float64}
  L         ::Float64
end
FullRepresentation() = FullRepresentation(Dict(), Dict(), Dict(), Dict(), 1.0)
FullRepresentation(full::FullRepresentation) = full   # identity down-convert

#---------------------------------------------------------------------------------------------------
"""
    ABRepresentation <: MultipoleRepresentation

Element-specific multipole form: only the final A/B field integrals.

`A` and `B` map each multipole order to its skew and normal field integral, respectively.
Built from a [`FullRepresentation`](@ref) via [`ABRepresentation(::FullRepresentation)`](@ref).
"""
struct ABRepresentation <: MultipoleRepresentation
  A::Dict{Int,Float64}
  B::Dict{Int,Float64}
end

#---------------------------------------------------------------------------------------------------
"""
    ABRepresentation(full::FullRepresentation)

Down-convert a `FullRepresentation` to A/B field integrals.

Combine each multipole's magnitude, length, and tilt into complex field integrals and store
their imaginary/real parts as the `A`/`B` coefficient dictionaries.
"""
function ABRepresentation(full::FullRepresentation)
  A = Dict{Int,Float64}()
  B = Dict{Int,Float64}()
  for mp in keys(full.magnitude)
    L    = full.integrated[mp] ? 1.0 : full.L
    t_n  = haskey(full.tilt, mp) ? full.tilt[mp] : 0.0
    fact = mp <= 20 ? 1 / factorial(mp) : 1 / factorial(big(mp))
    b_ia = fact * L * first([1 1im] * full.magnitude[mp]) * _tilt_rotation(mp, t_n)
    A[mp] = imag(b_ia)
    B[mp] = real(b_ia)
  end
  return ABRepresentation(A, B)
end

#---------------------------------------------------------------------------------------------------
"""
    _tilt_rotation(order::Int, tilt::Real)

Return the factor that rotates an `order` multipole of the given `tilt` into normal and skew
parts.

A tilt of `T` rotates an order-`N` field by `(N+1) * T` in the normal/skew plane: both PALS and
Bmad write the field as `(1/N!) (normal + i * skew) exp(-i (N+1) T)`.
"""
_tilt_rotation(order::Int, tilt::Real) = exp(-1im * (order + 1) * tilt)

#---------------------------------------------------------------------------------------------------
"""
    _fill_multipoles!(full::FullRepresentation, mmP, name)

Populate `full` from a PALS `MagneticMultipoleP` map.

Parse each key of `mmP` into a multipole order and store its magnitude, `normalized`,
`integrated`, and `tilt` attributes in `full`; `name` is used in error messages. Return `full`.
"""
function _fill_multipoles!(full::FullRepresentation, mmP, name)
  for mmkey in keys(mmP)
    order = parse(Int, filter(isdigit, mmkey))
    if startswith(mmkey, "tilt")
      haskey(full.tilt, order) && error("$name conflicting multipole definitions $mmkey")
      full.tilt[order] = Float64(mmP[mmkey])
    else
      ns = mmkey[2] == 'n' ? 1 : 2
      if !haskey(full.magnitude, order)
        full.integrated[order] = (mmkey[end] == 'L')
        full.normalized[order] = (mmkey[1] == 'K')
        full.magnitude[order]  = zeros(Float64, 2)
      end
      full.magnitude[order][ns] = Float64(mmP[mmkey])
    end
  end
  return full
end
