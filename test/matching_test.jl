using Test
using PALSParserJ
using PALSParserJ: match_names, parse_string, node_key

# The semantics of name matching are tested in PALSParserCpp; this checks the
# binding: that strings reach the C matcher and the nodes come back attached to
# the tree that was searched.
const MATCH_LATTICE = """
PALS:
  facility:
    - constants:
        - a_const: 0.3 * r_electron
        - a_two: 5
    - start:
        kind: BeginningEle
        ReferenceP:
          species_ref: electron
          E_tot_ref: 1e9
    - B1a:
        kind: Bend
        length: 1.2
        BendP:
          e1: 0.1
          g_ref: 0.02
    - Q1:
        kind: Quadrupole
        length: 0.5
    - main:
        kind: BeamLine
        line:
          - start
          - B1a
          - Q1
          - B1a
    - lat1:
        kind: Lattice
        branches:
          - main
"""

@testset "Name Matching" begin
  root = parse_string(MATCH_LATTICE)
  lat = mktempdir() do dir
    file = joinpath(dir, "match.pals.yaml")
    write(file, MATCH_LATTICE)
    parse_and_expand_pals(file; problems = :none)
  end

  @testset "constants by bare name" begin
    m = match_names(root, "a_const")
    @test length(m) == 1
    @test node_key(m[1]) == "a_const"
    @test String(m[1]) == "0.3 * r_electron"
    @test Set(node_key.(match_names(root, "a_.*"))) == Set(["a_const", "a_two"])
  end

  @testset "definitions before expansion" begin
    m = match_names(root, "B1a>length")
    @test length(m) == 1
    @test String(m[1]) == "1.2"
    m = match_names(root, "main>>Q1")
    @test length(m) == 1
    @test String(m[1]) == "Q1"
  end

  @testset "elements of the expanded lattice" begin
    m = match_names(lat.full_expanded, "B1a")
    @test length(m) == 2
    @test all(node_key(n) == "B1a" && is_map(n) for n in m)
    @test String.(match_names(lat.full_expanded, "B1a#2>element_index")) == ["4"]
    @test length(match_names(lat.full_expanded, "B1a#1:Q1")) == 2
    @test isempty(match_names(lat.full_expanded, "(unclosed"))
  end

  @testset "returned nodes belong to the searched tree" begin
    m = match_names(lat.full_expanded, "Q1>length")
    @test m[1].tree === lat.full_expanded.tree
  end
end
