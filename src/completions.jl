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

const identifier_pattern = r"^@?[_\p{L}][_\p{L}\p{N}!]*$"

moduleusings(mod) = ccall(:jl_module_usings, Any, (Any,), mod)

filtervalid(names) = @>> names map(string) filter(x->ismatch(identifier_pattern, x))

accessible(mod::Module) =
  [names(mod, true, true);
   map(names, moduleusings(mod))...] |> unique |> filtervalid

Base.getindex(b::Binding) = b.mod.(b.var)

completiontype(x) =
  isa(x, Module) ? "module" :
  isa(x, DataType) ? "type" :
  isa(x, Function) ? "function" :
  "constant"

function withmeta(completion::AString, mod::Module)
  isdefined(mod, symbol(completion)) || return completion
  b = Binding(mod, symbol(completion))
  x = b[]
  c = d(:text => completion,
        :type => completiontype(x),
        :rightLabel => string(b.mod))
  if isa(x, Function)
    c[:displayText] = signature(b)
    c[:description] = description(b)
  end
  c
end

withmeta(completions::Vector, mod::Module) =
  [withmeta(completion, mod) for completion in completions]

function namecompletions(mod::Module, qualified = false)
  if !qualified
    [withmeta(accessible(mod), mod); builtin_completions]
  else
    withmeta(filtervalid(names(mod, true)), mod)
  end
end

# Completions
# –––––––––––

const prefix_pattern = r"(@?[_\p{L}][_\p{L}\p{N}!]*\.?)+$"

function prefix(line, mod = Main)
  match = Base.match(prefix_pattern, line)
  match == nothing && return UTF8String[]
  split(match.match, ".")
end

function completions(line, mod = Main)
  pre = prefix(line)
  if !isempty(pre) && (mod = getthing(mod, pre[1:end-1])) != nothing
    return namecompletions(mod, length(pre)>1)
  end
  return []
end
