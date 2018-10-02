using Test, CodeTools
import Base.Docs: Binding

@test CodeTools.getthing("Base.sin") == sin
@test CodeTools.getthing(Base, [:sin]) == sin

@testset "documentation" begin
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
    """
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
    """
    foo = :bar

    @test CodeTools.hasdoc(foo) == true
    @test chomp(CodeTools.description(Binding(Main, :foo))) == "i'm a constant"
    @test CodeTools.signature(Binding(Main, :foo)) == nothing
    @test CodeTools.completiontype(foo) == "constant"
  end
end

# module detection tests
@testset "module detection" begin
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
  """,
  """
  :module Foo
  1+1
  end
  """,
  """
  bla.module
  foo
  end
  """,
  """
  begin
  module Foo
  2+2
  end
  1+1
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
  @test CodeTools.codemodule(code[5], 1) == ""
  @test CodeTools.codemodule(code[5], 2) == ""
  @test CodeTools.codemodule(code[5], 3) == ""
  @test CodeTools.codemodule(code[6], 1) == ""
  @test CodeTools.codemodule(code[6], 2) == ""
  @test CodeTools.codemodule(code[6], 3) == ""
  @test CodeTools.codemodule(code[7], 1) == ""
  @test CodeTools.codemodule(code[7], 3) == "Foo"
  @test CodeTools.codemodule(code[7], 5) == ""

  @test CodeTools.filemodule(normpath(joinpath(@__DIR__, "..", "src", "module.jl"))) == "CodeTools"

  @test CodeTools.includeline(normpath(joinpath(@__DIR__, "..", "src", "CodeTools.jl")), normpath(joinpath(@__DIR__, "..", "src", "utils.jl"))) == 5
end

@testset "completions" begin
  @test CodeTools.prefix("MacroTools.@") == ["MacroTools", "@"]
  @test length(CodeTools.completions("CodeTools.pre")) > 0
  @test "LinearAlgebra" in CodeTools.stdlibs()
end
