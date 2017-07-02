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

# module detection tests
code = ["""
module Mod1
[x for x=1:2]
end
1+1
""",
"""
module Mod2
module Foo
# for
end
1+1
""",
"""
module Mod3
abstract foo
end
""",
"""
module Mod4
bitstype 8 foo
(i for i = 1:10)
end
"""

]

@test CodeTools.codemodule(code[1], 2) == "Mod1"
@test CodeTools.codemodule(code[1], 4) == ""
@test CodeTools.codemodule(code[2], 3) == "Mod2.Foo"
@test CodeTools.codemodule(code[2], 5) == "Mod2"
@test CodeTools.codemodule(code[3], 2) == "Mod3"
@test CodeTools.codemodule(code[3], 3) == ""
@test CodeTools.codemodule(code[4], 2) == "Mod4"
@test CodeTools.codemodule(code[4], 3) == "Mod4"
@test CodeTools.codemodule(code[4], 4) == ""

@testset "completions" begin
  @test CodeTools.prefix("MacroTools.@") == ["MacroTools", "@"]
  @test length(CodeTools.completions("CodeTools.pre")) > 0
end
