moduleusings(mod) = ccall(:jl_module_usings, Any, (Any,), mod)

function findsource(mod::Module, var::Symbol, seen = Set{Module}())
    mod in seen && return
    var in names(mod, true) && return mod
    push!(seen, mod)
    sources = filter(m -> m ≠ nothing && !(m in seen),
                     map(m -> findsource(m, var, seen),
                         moduleusings(mod)))
    isempty(sources) && return
    return collect(sources)[1]
end

immutable Binding
    mod::Module
    var::Symbol

    function Binding(mod::Module, var::Symbol)
        mod′ = findsource(mod, var)
        mod′ == nothing && error("$mod.$var not found")
        return new(mod′, var)
    end
end

macro var(x)
    (mod, x) = @match x begin
        mod_.x_    => (mod, x)
        (mod_.@x_) => (mod, x)
        (@x_)      => (nothing, x)
        x_""       => (nothing, x)
        _          => isa(x, Symbol) ? (nothing, x) :
                        error("Invalid @var syntax `$x`")
    end
    mod == nothing && (mod = module_name(current_module()))
    :(Binding($(esc(mod)), $(Expr(:quote, x))))
end

Base.show(io::IO, x::Binding) = print(io, "•$(x.mod).$(x.var)")

Base.getindex(x::Binding) = x.mod.(x.var)
