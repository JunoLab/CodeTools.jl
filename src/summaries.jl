import Base.Docs: Binding, @var
using Markdown: MD, Code, Paragraph, plain

# flat_content(md) = md
# flat_content(xs::Vector) = reduce((xs, x) -> vcat(xs,flat_content(x)), [], xs)
# flat_content(md::MD) = flat_content(md.content)
flatten(md::MD) = MD(flat_content(md))

# Faster version

function flat_content!(xs, out = [])
  for x in xs
    if isa(x, MD)
      flat_content!(x.content, out)
    else
      push!(out, x)
    end
  end
  return out
end

flat_content(md::MD) = flat_content!(md.content)

function hasdoc(b::Binding)
    for m in Docs.modules
        meta = Docs.meta(m)
        if haskey(meta, b) || haskey(meta, b[])
            return true
        end
    end
    false
end

hasdoc(b) = hasdoc(Docs.aliasof(b, typeof(b)))

function trygetdoc(b)
  docs = try
    Docs.doc(b)
  catch
    ""
  end
end

function fullsignature(b::Binding)
  hasdoc(b) || return
  docs = trygetdoc(b)
  isa(docs, MD) || return
  md = flatten(docs).content
  first = length(md) > 0 ? md[1] : ""
  code =
    isa(first, Code) ? first.code :
    isa(first, Paragraph) && isa(md[1], Code) ?
      md[1].code :
      ""
  if startswith(code, string(b.var))
    split(code, "\n")[1]
  end
end

function signature(b::Binding)
  sig = fullsignature(b)
  sig == nothing && return
  replace(sig, r" -> .*$" => "")
end

function returns(b::Binding)
  r = r" -> (.*)"
  sig = fullsignature(b)
  sig == nothing && return
  if occursin(r, sig)
    ret = match(r, sig).captures[1]
    if length(ret) < 10
      ret
    end
  end
end

function description(b::Binding)
  hasdoc(b) || return
  docs = trygetdoc(b)
  isa(docs, MD) || return
  md = flatten(docs).content
  length(md) > 0 || return
  first = md[1]
  if isa(first, Code)
    length(md) < 2 && return
    first = md[2]
  end
  if isa(first, Paragraph)
    desc = plain(first)
    return length(desc) > 100 ?
      desc[1:nextind(desc, 0, 99)]*"..." :
      desc
  end
end
