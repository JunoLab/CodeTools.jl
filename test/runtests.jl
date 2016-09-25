using Base.Test, CodeTools

@test CodeTools.getthing("Base.fft") == fft
@test CodeTools.getthing(Base, [:fft]) == fft

@test CodeTools.filemodule(Pkg.dir("CodeTools", "src", "module.jl")) == "CodeTools"

let
  function func(x)
    infunc = (y) -> y^x
    return infunc
  end

  @test CodeTools.hasdoc(func(3)) == false
end
