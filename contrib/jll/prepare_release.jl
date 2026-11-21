using TOML
root = dirname(@__DIR__)
wrapper = joinpath(root, "generated-jll")
project = TOML.parsefile(joinpath(wrapper, "Project.toml"))
@assert project["name"] == "PALSParserCpp_jll"
@assert project["uuid"] == "abf197fe-9414-589a-856b-7f7f8c52d4af"
tag = "PALSParserCpp-v" * project["version"]
base = "https://github.com/" * ENV["REPOSITORY"] * "/releases/download/" * tag
artifacts = TOML.parsefile(joinpath(wrapper, "Artifacts.toml"))
for entries in values(artifacts), entry in entries, download in entry["download"]
    filename = last(split(download["url"], '/'))
    @assert isfile(joinpath(root, "products", filename))
    download["url"] = base * "/" * filename
end
open(joinpath(wrapper, "Artifacts.toml"), "w") do io
    TOML.print(io, artifacts; sorted=true)
end
for file in ("Project.toml", "Artifacts.toml", "LICENSE", "README.md", "src")
    cp(joinpath(wrapper, file), joinpath(root, file); force=true)
end
open(joinpath(root, "README.md"), "a") do io
    println(io, "\n## Native-library distribution notes\n")
    println(io, "This is a self-hosted release. Upstream PALSParserCpp has no declared license; this packaging does not change upstream's declaration. Native dependency notices are included in the artifact. Complete corresponding source and build scripts are attached to this release. The generated Julia wrapper license is distinct from native code licensing.")
end
write(joinpath(@__DIR__, "release-tag"), tag)
write(joinpath(@__DIR__, "release-notes.txt"), """
Platform-specific PALSParserCpp JLL artifacts built from pinned upstream sources.

Upstream parser commit: 949c29462204c46d0c520e41dea0c582a8adcb8b.
Native import and C API checks: Linux (Julia 1.10), ARM/Intel macOS, Windows.
Full corresponding source, submodules and packaging/build scripts are attached.

The generated Julia wrapper's license is separate from native-library licensing.
Upstream PALSParserCpp currently has no declared license; this release does not
claim that upstream has adopted GPLv2 or another license. The linked APC
component ships GPLv2 text; dependency notices are retained in the artifacts.
This is a self-hosted pals-project package, not a Yggdrasil/General registration.
""")
