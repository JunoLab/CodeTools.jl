# Qualified names → objects

function getthing(mod::Module, name::Vector, default = nothing)
  thing = mod
  for sym in name
    sym = Symbol(sym)
    if isdefined(thing, sym) && !Base.isdeprecated(mod, sym)
      thing = getfield(thing, sym)
    else
      return default
    end
  end
  return thing
end

getthing(mod::Module, name::AbstractString, default = nothing) =
  name == "" ?
    default :
    @as x name split(x, ".", keepempty=false) map(Symbol, x) getthing(mod, x, default)

getthing(mod::Module, ::Nothing, default) = default

getthing(mod::Module, x, default) = error("can't get $x from a module")

getthing(args...) = getthing(Main, args...)

# include_string with line numbers

function Base.include_string(mod, s::AbstractString, fname::AbstractString, line::Integer)
  include_string(mod, "\n"^(line-1)*s, fname)
end

function getmodule(mod::String)
  mods = split(mod, '.')
  if length(mods) == 1
    getmod(mod)
  else
    getsubmod(mods)
  end
end

function getmod(mod)
  inds = filter(x -> x.name==mod, collect(keys(Base.loaded_modules)))
  if length(inds) == 1
    return get(Base.loaded_modules, first(inds), Main)
  elseif length(inds) == 0
    return Main
  else
    @warn "no support for multiple packages with the same name yet"
    return Main
  end
end

function getsubmod(mods)
  mod = getmod(popfirst!(mods))
  for submod in mods
    submod = Symbol(submod)
    if isdefined(mod, submod)
      mod = getfield(mod, submod)
    else
      return mod
    end
  end
  mod
end

# Get the current module for a file/pos

function getmodule(code, pos; filemod = nothing)
  codem = codemodule(code, pos)
  modstr = (codem != "" && filemod != nothing) ? "$filemod.$codem" :
           codem == "" ? filemod : codem
  getthing(modstr, Main)
end
