__precompile__()

module CodeTools

using Lazy, LNR

include("utils.jl")
include("eval.jl")
include("module.jl")
include("summaries.jl")

# # Summaries shims
# signature(_) = nothing
# description(_) = nothing

include("completions.jl")
include("doc.jl")

end # module
