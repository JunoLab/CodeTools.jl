module CodeTools

using Lazy, LNR

include("utils.jl")
include("eval.jl")
include("module.jl")
include("summaries.jl")

include("completions.jl")
include("doc.jl")

end # module
