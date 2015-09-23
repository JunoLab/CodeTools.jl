module CodeTools

using MacroTools

using LNR, Lazy, Requires, Compat

include("parse/parse.jl")
include("eval.jl")
include("module.jl")
include("utils/bindings.jl")
include("completions.jl")
include("doc.jl")

end # module
