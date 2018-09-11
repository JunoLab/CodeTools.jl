import Base.Docs: Binding

# Keywords
# ––––––––

const builtins = ["abstract", "baremodule", "begin", "bitstype", "break",
                  "catch", "ccall", "const", "continue", "do", "else",
                  "elseif", "end", "export", "finally", "for", "function",
                  "global", "if", "immutable", "import", "importall", "let",
                  "local", "macro", "module", "quote", "return", "try", "type",
                  "typealias", "using", "while"]

const builtin_completions =
  [d(:text=>k, :type=>:keyword)
   for k in builtins]

# Module completions
# ––––––––––––––––––

const identifier_pattern = r"^@?[_\p{L}][\p{Xwd}!]*+$"

_names(mod; all = false, imported = false) = filter!(x -> !Base.isdeprecated(mod, Symbol(x)), names(mod, all=all, imported=imported))

moduleusings(mod) = ccall(:jl_module_usings, Any, (Any,), mod)

filtervalid(names) = @>> names map(string) filter(x->occursin(identifier_pattern, x))

accessible(mod::Module) =
  [_names(mod, all=true, imported=true);
   map(_names, moduleusings(mod))...] |> unique |> filtervalid

Base.getindex(b::Binding) = isdefined(b.mod, b.var) ? getfield(b.mod, b.var) : nothing

completiontype(x) =
  isa(x, Module)   ? "module" :
  isa(x, DataType) ? "type"   :
  isa(x, Function) ? "λ"      :
                     "constant"

const meta_cache = Dict{Any,Any}()

function withmeta(completion::AbstractString, mod::Module)
  isdefined(mod, Symbol(completion)) || return completion
  b = Binding(mod, Symbol(completion))
  mod = b.mod
  haskey(meta_cache, (mod, completion)) && return meta_cache[(mod, completion)]
  x = b[]
  c = d(:text => completion,
        :type => startswith(completion, "@") ? "macro" : completiontype(x),
        :rightLabel => string(mod))
  c[:displayText] = signature(b)
  c[:description] = description(b)
  c
end

for name in map(string, _names(Base))
  meta_cache[(Base, name)] = withmeta(name, Base)
end

withmeta(completions::Vector, mod::Module) =
  [withmeta(completion, mod) for completion in completions]

function namecompletions_(mod::Module, qualified = false)
  if !qualified
    [withmeta(accessible(mod), mod); builtin_completions]
  else
    withmeta(filtervalid(_names(mod, all=true)), mod)
  end
end

const namecompletions = memoize_debounce(namecompletions_)

const prefix_pattern = r"(@?[_\p{L}][\p{Xwd}!]*+\.?@?)+$|@$"

function prefix(line)
  match = Base.match(prefix_pattern, line)
  match == nothing && return String[]
  split(match.match, ".")
end

# Path Completions
# ––––––––––––––––

function funcprefix(line)
  m = match(r"\b([^\s]*)\(([^\)]*)$", line) # matches `foo(bar`
  m == nothing && return
  return m.captures[1], m.captures[2]
end

function pathprefix(line)
  m = match(r"\"?([\w\\/:\-.]*)$", line)
  m == nothing && return
  return m.match, m.captures[1]
end

function stringmeta(cs, prefix)
  map(c -> Dict(:text => c, :_prefix => prefix, :type => :file), cs)
end

function pathmeta(cs, path, prefix)
  stringmeta(map(c -> replace(joinpath(path, c), r"^\./" => ""), cs), prefix)
end

function children(dir, ext = ""; depth = 0, out = String[], prefix = "")
  isdir(dir) || return []
  for f in readdir(dir)
    path = joinpath(dir, f)
    if isfile(path) && ext ≠ nothing && endswith(path, ext)
      push!(out, joinpath(prefix, f))
    elseif isdir(path)
      push!(out, joinpath(prefix, f, ""))
      if depth > 0
        children(path, ext, depth = depth-1, out = out, prefix = joinpath(prefix, f))
      else
      end
    end
  end
  return out
end

function includepath()
  path = Base.source_path()
  path == nothing && return pwd()
  return dirname(path)
end

function pathcompletions(line)
  m = funcprefix(line)
  m == nothing && return
  func, pre = m
  m = pathprefix(pre)
  m == nothing && return
  pre, path = m
  dir = dirname(path)
  try
    if func == "include"
      pathmeta(children(joinpath(includepath(), dir), ".jl", depth = 2), dir, path)
    elseif func == "readcsv"
      pathmeta(children(joinpath(pwd(), dir), ".csv", depth = 2), dir, path)
    elseif func == "cd"
      pathmeta(children(joinpath(pwd(), dir), nothing), dir, path)
    elseif func == "open"
      pathmeta(children(joinpath(pwd(), dir)), dir, path)
    end
  catch e
    []
  end
end

# Package Completions
# –––––––––––––––––––
# not sure why this errors with "ArgumentError: Module Pkg3 not found in current path."

import Pkg

pkgmeta(xs) = [Dict(:text => x, :type => "package") for x in xs]

function _stdlibs()
  ver = string("v", VERSION.major, ".", VERSION.minor)
  srcdir = joinpath(Sys.BINDIR,"..","..","stdlib",ver)
  releasedir = joinpath(Sys.BINDIR,"..","share","julia","stdlib",ver)
  return ispath(srcdir) ? readdir(srcdir) :
                          ispath(releasedir) ? readdir(releasedir) : []
end

const stdlibs = memoize(_stdlibs)

function pkgcompletions(line)
  if occursin(r"^using|^import", line)
    return pkgmeta(sort!(append!(collect(keys(Pkg.API.installed())), stdlibs())))
  end
end

# Completions
# –––––––––––

const providers = [pkgcompletions, pathcompletions]

function completions(line::AbstractString, mod::Module = Main; default = true)
  for provider in providers
    cs = provider(line)
    cs ≠ nothing && return cs
  end
  pre = prefix(line)
  mod = getthing(mod, pre[1:end-1])
  if isa(mod, Module)
    qualified = length(pre) > 1
    !(qualified || default) && return
    return namecompletions(mod, qualified)
  end
  return []
end

completions(mod::Module) = completions("", mod, default = true)
