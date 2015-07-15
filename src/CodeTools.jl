module CodeTools

using LNR, Lazy, Requires

include("base.jl")
include("parse/parse.jl")
include("eval.jl")
include("module.jl")
include("completions.jl")
include("doc.jl")

@lazymod ProfileView "profile/profile.jl"

end # module
