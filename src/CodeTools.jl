module CodeTools

using LNR, Lazy, Requires

include("parse/parse.jl")
include("eval.jl")
include("module.jl")
include("completions.jl")
include("doc.jl")

end # module
