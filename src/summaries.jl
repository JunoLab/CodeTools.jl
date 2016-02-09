import Base.Docs: Binding, @var
import Base.Markdown: MD, Code, Paragraph

flat_content(md) = md
flat_content(xs::Vector) = reduce((xs, x) -> vcat(xs,flat_content(x)), [], xs)
flat_content(md::MD) = flat_content(md.content)

flatten(md::MD) = MD(flat_content(md))

function fullsignature(b::Binding)
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

signature(b::Binding) = replace(fullsignature(b), r" -> .*$", "")

function returns(b::Binding)
  r = r" -> (.*)"
  sig = fullsignature(b)
  if ismatch(r, sig)
    ret = match(r, sig).captures[1]
    if length(ret) < 10
      ret
    end
  end
end

function summary(b::Binding)
  md = flatten(Docs.doc(b))
  first = md.content[1]
  isa(first, Code) && (first = md.content[2])
  if isa(first, Paragraph)
    return Markdown.plain(first)
  end
end
