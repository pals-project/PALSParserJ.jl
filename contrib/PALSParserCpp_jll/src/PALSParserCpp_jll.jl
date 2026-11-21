# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule PALSParserCpp_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("PALSParserCpp")
JLLWrappers.@generate_main_file("PALSParserCpp", Base.UUID("abf197fe-9414-589a-856b-7f7f8c52d4af"))
end  # module PALSParserCpp_jll
