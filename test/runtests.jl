using Base.Test, CodeTools
import Base.Docs: Binding

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

let
  @doc """
    docfunc(x)
docs

more docs which aren't in the description
  """ ->
  function docfunc(x) end

  @test CodeTools.hasdoc(docfunc) == true
  @test chomp(CodeTools.description(Binding(Main, :docfunc))) == "docs"
  @test CodeTools.signature(Binding(Main, :docfunc)) == "docfunc(x)"
  @test CodeTools.completiontype(docfunc) == "λ"
end

let
  @doc """
i'm a constant

with multiline docs
  """ ->
  const foo = :bar

  @test CodeTools.hasdoc(foo) == true
  @test chomp(CodeTools.description(Binding(Main, :foo))) == "i'm a constant"
  @test CodeTools.signature(Binding(Main, :foo)) == nothing
  @test CodeTools.completiontype(foo) == "constant"
end
