export completions, allcompletions, complete

const builtins = ["abstract", "baremodule", "begin", "bitstype", "break",
                  "catch", "ccall", "const", "continue", "do", "else",
                  "elseif", "end", "export", "finally", "for", "function",
                  "global", "if", "immutable", "import", "importall", "let",
                  "local", "macro", "module", "quote", "return", "try", "type",
                  "typealias", "using", "while"]

function lastcall(scopes)
  for i = length(scopes):-1:1
    scopes[i].kind == :call && return scopes[i].name
  end
end

"""
Takes a block of code and a cursor and returns autocomplete data.
"""
function completions(code, cursor; mod = Main, file = nothing)
  ident = getqualifiedname(code, cursor)
  line = precursor(lines(code)[cursor.line], cursor.column)
  scs = scopes(code, cursor)
  sc = scs[end]
  call = lastcall(scs)

  if sc.kind == :using
    pkg_completions(packages())
  elseif call != nothing && (f = getthing(call, mod); haskey(fncompletions, f))
    fncompletions[f](@d(:mod => mod,
                        :file => file,
                        :input => precursor(line, cursor.column)))
  elseif sc.kind in (:string, :multiline_string, :comment, :multiline_comment)
    nothing
  elseif (q = qualifier(line)) != nothing
    thing = getthing(mod, q, nothing)
    if isa(thing, Module)
      @> thing names(true) filtervalid
    elseif thing != nothing && sc.kind == :toplevel
      @> thing names filtervalid
    end
  elseif isnum(line)
    nothing
  elseif ident != ""
    name = split(ident, ".")[end]
    @>> accessible(mod) filter(c -> isempty(setdiff(name, c)))
  end
end

"""
Takes a file of code and a cursor and returns autocomplete data.
"""
function allcompletions(code, cursor; mod = Main, file = nothing)
  block, _, cursor′ = getblockcursor(code, cursor)
  cs = completions(block, cursor′, mod = mod, file = file)
  cs == nothing && return nothing
  return cs
end

# Module completions
# ––––––––––––––––––

moduleusings(mod) = ccall(:jl_module_usings, Any, (Any,), mod)

filtervalid(names) = @>> names map(string) filter(x->!ismatch(r"#", x))

accessible(mod::Module) =
  [names(mod, true, true);
   map(names, moduleusings(mod))...;
   builtins] |> unique |> filtervalid

function qualifier(s)
  m = match(Regex("((?:$(identifier.pattern)\\.)+)(?:$(identifier.pattern))?\$"), s)
  m == nothing ? m : m.captures[1]
end

isnum(s) = ismatch(r"(0x[0-9a-zA-Z]*|[0-9]+)$", s)

# Custom completions
# ––––––––––––––––––

const fncompletions = Dict{Function,Function}()

complete(completions::Function, f::Function) =
  fncompletions[f] = completions

# Include completions
# TODO: cd completions

const pathpattern = r"[a-zA-Z0-9_\.\\/]*"

includepaths(path) =
  @>> dirsnearby(path, ascend = 0) jl_files map(p->p[length(path)+2:end])

includepaths(Pkg.dir("CodeTools", "src"))

# TODO: custom prefixes
# complete(include) do info
#   file = info[:file]
#   dir = file == nothing ? pwd() : dirname(file)
#   includepaths(dir)
# end

# Package manager completions

# TODO: stringify properly

packages(dir = Pkg.dir()) =
  @>> dir readdir filter(x->!ismatch(r"^\.|^METADATA$|^REQUIRE$", x))

all_packages() = packages(Pkg.dir("METADATA"))

required_packages() =
  @>> Pkg.dir("REQUIRE") readall lines

unused_packages() = setdiff(all_packages(), required_packages())

for f in (Pkg.add, Pkg.clone)
  complete(f) do _
    unused_packages()
  end
end

for f in (Pkg.checkout, Pkg.free, Pkg.rm, Pkg.publish, Pkg.build, Pkg.test)
  complete(f) do _
    packages()
  end
end
