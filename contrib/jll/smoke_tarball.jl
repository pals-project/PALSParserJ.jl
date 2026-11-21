# Import a generated JLL against the downloaded native tarball, not a local build.
using Libdl, Pkg, UUIDs, TOML
using Pkg.Artifacts, Base.BinaryPlatforms
recipe = ENV["JLL_RECIPE"]
products, wrapper = abspath.(ARGS)
Pkg.activate(; temp=true)
arch_token = string(Sys.ARCH)
os_token = Sys.isapple() ? "apple-darwin" : Sys.iswindows() ? "mingw32" : "linux-gnu"
files = filter(readdir(products; join=true)) do f
    b = basename(f)
    startswith(b, recipe * ".v") && occursin(arch_token, b) && occursin(os_token, b) &&
        !occursin("logs", b) && endswith(b, ".tar.gz")
end
length(files) == 1 || error("Expected exactly one native tarball, got: $files")
artifacts_toml = joinpath(wrapper, "Artifacts.toml")
meta = artifact_meta(recipe, artifacts_toml; platform=HostPlatform())
meta === nothing && error("Generated wrapper has no artifact for $(HostPlatform())")
expected = Base.SHA1(meta["git-tree-sha1"])
actual = create_artifact() do prefix
    Pkg.PlatformEngines.unpack(only(files), prefix)
end
actual == expected || error("Downloaded artifact tree does not match the generated JLL metadata")
# Installing the matching artifact first avoids the builder's file:// download
# URLs, which deliberately point at a directory on the build runner.
Pkg.develop(path=wrapper)
Pkg.instantiate()
project = TOML.parsefile(joinpath(wrapper, "Project.toml"))
jll = Base.require(Base.PkgId(UUID(project["uuid"]), project["name"]))
symbol = Dict("PALSParserCpp" => :libPALSParserCpp_path, "rapidyaml" => :libryml_path,
              "AtomicAndPhysicalConstantsCLib" => :libapc_path)[recipe]
handle = Libdl.dlopen(getproperty(jll, symbol))
if recipe == "PALSParserCpp"
    fn = Libdl.dlsym(handle, :evaluate_pals_expression)
    ok = Ref{Bool}(false)
    result = ccall(fn, Cdouble, (Cstring, Ref{Bool}), "2 + 3 * 4", ok)
    @assert ok[] && result == 14
    tree = ccall(Libdl.dlsym(handle, :create_empty_tree), Ptr{Cvoid}, ())
    @assert tree != C_NULL
    ccall(Libdl.dlsym(handle, :delete_tree), Cvoid, (Ptr{Cvoid},), tree)
end
println("Imported generated $(project["name"]) artifact on $(Sys.MACHINE)")
