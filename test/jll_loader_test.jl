using Test, PALSParserJ

@testset "JLL loader and explicit developer overrides" begin
    withenv("PALS_PARSER_CPP_LIB" => nothing, "PALS_PARSER_CPP_DIR" => nothing) do
        @test isempty(PALSParserJ._libparser_candidates())
    end
    mktempdir() do dir
        missing = joinpath(dir, "missing." * PALSParserJ.Libdl.dlext)
        withenv("PALS_PARSER_CPP_LIB" => missing) do
            @test PALSParserJ._libparser_candidates() == [abspath(missing)]
            @test_throws "Explicit PALS parser override does not exist" PALSParserJ._find_libparser()
        end
        # Path resolution must not dlopen here: that happens only at the first C call.
        present = joinpath(dir, "present." * PALSParserJ.Libdl.dlext)
        write(present, "path-resolution fixture")
        withenv("PALS_PARSER_CPP_LIB" => present) do
            @test PALSParserJ._find_libparser() == abspath(present)
        end
    end
end
