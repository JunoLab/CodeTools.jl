import Base.Docs: Binding, @var
import Base.Markdown: MD, Code, Paragraph

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

hasdoc(b::Binding) =
  Docs.get_obj_meta(b) != nothing ||
  Docs.get_obj_meta(b[]) != nothing

function fullsignature(b::Binding)
  hasdoc(b) || return
  first = flatten(Docs.doc(b)).content[1]
  code =
    isa(first, Code) ? first.code :
    isa(first, Paragraph) && isa(first.content[1], Code) ?
      first.content[1].code :
    ""
  if Base.startswith(code, string(b.var))
    split(code, "\n")[1]
  end
end

function signature(b::Binding)
  sig = fullsignature(b)
  sig == nothing && return
  replace(sig, r" -> .*$", "")
end

function returns(b::Binding)
  r = r" -> (.*)"
  sig = fullsignature(b)
  sig == nothing && return
  if ismatch(r, sig)
    ret = match(r, sig).captures[1]
    if length(ret) < 10
      ret
    end
  end
end

function description(b::Binding)
  hasdoc(b) || return
  md = flatten(Docs.doc(b))
  first = md.content[1]
  if isa(first, Code)
    length(md.content) < 2 && return
    first = md.content[2]
  end
  if isa(first, Paragraph)
    desc = Markdown.plain(first)
    return length(desc) > 100 ?
      desc[1:100]*" ..." :
      desc
  end
end
