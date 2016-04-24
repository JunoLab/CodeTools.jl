# TODO: fix getqualifiedname -- doesn't work for e.g. functions with underscores (include_string)
function thingorfunc(code, cursor, mod = Main; name = getqualifiedname(code, cursor))
  name == "" && (name = lastcall(scopes(code, cursor)))
  name == nothing ? name : getthing(mod, name, nothing)
end

function doc(code, cursor, mod::Module = Main)
  name = getqualifiedname(code, cursor)
  thing = thingorfunc(code, cursor, mod; name = name)
  doc(thing, mod)
end

function doc(word::AString, mod::Module = Main)
  isdefined(mod, symbol(word)) || return Base.Markdown.parse("`$word` not defined")
  b = Binding(mod, symbol(word))
  hasdoc(b) ? Docs.doc(b) : "No documentation found."
end

methodsorwith(word::AString, mod::Module = Main) = isdefined(mod, symbol(word)) ?
                                                   methodsorwith(include_string(word)) : []

methodsorwith(word::Union{Module, DataType}) = methodswith(word)

methodsorwith(word::Function) = methods(word)

methodsorwith(word) = []

function methodsorwith(code, cursor, mod = Main)
  thing = thingorfunc(code, cursor, mod)
  thing == nothing && return
  methodsorwith(thing)
end
