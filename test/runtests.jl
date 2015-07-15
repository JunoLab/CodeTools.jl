using Base.Test, CodeTools

@test CodeTools.getthing("Base.fft") == fft
@test CodeTools.getthing(Base, [:fft]) == fft

@test CodeTools.filemodule(Pkg.dir("CodeTools", "src", "module.jl")) == "CodeTools"

include("utils.jl")
include("scope.jl")
include("display.jl")
