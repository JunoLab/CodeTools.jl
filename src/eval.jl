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
    @as _ name split(_, ".", keep=false) map(Symbol, _) getthing(mod, _, default)

getthing(mod::Module, ::Void, default) = default

getthing(args...) = getthing(Main, args...)

# include_string with line numbers

function Base.include_string(s::AbstractString, fname::AbstractString, line::Integer)
  include_string("\n"^(line-1)*s, fname)
end

function Base.include_string(mod::Module, args...)
  eval(mod, :(include_string($(args...))))
end

# Get the current module for a file/pos

function getmodule(code, pos; filemod = nothing)
  codem = codemodule(code, pos)
  modstr = (codem != "" && filemod != nothing) ? "$filemod.$codem" :
           codem == "" ? filemod : codem
  getthing(modstr, Main)
end
