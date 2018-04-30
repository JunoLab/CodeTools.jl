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

# Get the current module for a file/pos

function getmodule(code, pos; filemod = nothing)
  codem = codemodule(code, pos)
  modstr = (codem != "" && filemod != nothing) ? "$filemod.$codem" :
           codem == "" ? filemod : codem
  getthing(modstr, Main)
end
