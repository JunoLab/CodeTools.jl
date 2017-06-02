using Tokenize

# –––––––––––––––
# Some file utils
# –––––––––––––––

function readdir′(dir)
  try
    readdir(dir)
  catch e
    String[]
  end
end

isdir′(f) = try isdir(f) catch e false end
isfile′(f) = try isfile(f) catch e false end

files(dir) =
  @_ dir readdir′(_) map!(f->joinpath(dir, f), _ ,_) filter!(isfile′, _)

dirs(dir) =
  @_ dir readdir′(_) filter!(f->!startswith(f, "."), _) map!(f->joinpath(dir, f), _, _) filter!(isdir′, _)

jl_files(dir::AbstractString) = @>> dir files filter!(f->endswith(f, ".jl"))

function jl_files(set)
  files = Set{String}()
  for dir in set, file in jl_files(dir)
    push!(files, file)
  end
  return files
end

"""
Takes a start directory and returns a set of nearby directories.
"""
# Recursion + Mutable State = Job Security
function dirsnearby(dir; descend = 1, ascend = 1, set = Set{String}())
  push!(set, dir)
  if descend > 0
    for down in dirs(dir)
      if !(down in set)
        push!(set, down)
        descend > 1 && dirsnearby(down, descend = descend-1, ascend = 0, set = set)
      end
    end
  end
  ascend > 0 && dirsnearby(dirname(dir), descend = descend, ascend = ascend-1, set = set)
  return set
end

# ––––––––––––––
# The Good Stuff
# ––––––––––––––
const SCOPE_STARTERS = [Tokens.BEGIN,
                        Tokens.WHILE,
                        Tokens.IF,
                        Tokens.FOR,
                        Tokens.TRY,
                        Tokens.FUNCTION,
                        Tokens.MACRO,
                        Tokens.LET,
                        Tokens.TYPE,
                        Tokens.IMMUTABLE,
                        Tokens.DO,
                        Tokens.QUOTE,
                        Tokens.STRUCT]

const MODULE_STARTERS = [Tokens.MODULE, Tokens.BAREMODULE]

"""
Takes Julia source code and a line number, gives back the string name
of the module at that line.
"""
function codemodule(code, line)
  stack = String[]
  # count all unterminated block openers, brackets, and parens
  n_openers = 0
  n_brackets = 0
  n_parens = 0
  # index of next modulename token
  next_modulename = -1

  ts = tokenize(code)

  for (i, t) in enumerate(ts)
    Tokens.startpos(t)[1] > line && break

    # Ignore everything in brackets or parnetheses, because any scope started in
    # them also needs to be closed in them. That way, we don't need special
    # handling for comprehensions and `end`-indexing.
    if Tokens.kind(t) == Tokens.LSQUARE
      n_brackets += 1
    elseif n_brackets > 0
      if Tokens.kind(t) == Tokens.RSQUARE
        n_brackets -= 1
      end
    elseif Tokens.kind(t) == Tokens.LPAREN
      n_parens += 1
    elseif n_parens > 0
      if Tokens.kind(t) == Tokens.RPAREN
        n_parens -= 1
      end
    elseif Tokens.exactkind(t) in MODULE_STARTERS  # new module
      next_modulename = i + 2
    elseif i == next_modulename && Tokens.kind(t) == Tokens.IDENTIFIER
      push!(stack, Tokens.untokenize(t))
    elseif Tokens.exactkind(t) in SCOPE_STARTERS  # new non-module scope
      n_openers += 1
    elseif Tokens.exactkind(t) == Tokens.END  # scope ended
      n_openers == 0 ? (!isempty(stack) && pop!(stack)) : n_openers -= 1
    end
  end

  return join(stack, ".")
end

codemodule(code, pos::Cursor) = codemodule(code, pos.line)

"""
Takes a given Julia source file and another (absolute) path, gives the
line on which the path is included in the file or 0.
"""
function includeline(file::AbstractString, included_file::AbstractString)
  i = 0
  open(file) do io
    for (index, line) in enumerate(eachline(io))
      m = match(r"include\(\"([a-zA-Z_\.\\/]*)\"\)", line)
      if m != nothing && normpath(joinpath(dirname(file), m.captures[1])) == included_file
        i = index
        break
      end
    end
  end
  return i
end

"""
Takes an absolute path to a file and returns the (file, line) where that
file is included or nothing.
"""
function find_include(path::AbstractString)
  for file in @> path dirname dirsnearby jl_files
    line = includeline(file, path)
    line > 0 && (return file, line)
  end
end

"""
Takes an absolute path to a file and returns a string
representing the module it belongs to.
"""
function filemodule_(path::AbstractString)
  loc = find_include(path)
  if loc != nothing
    file, line = loc
    mod = codemodule(readstring(file), line)
    super = filemodule(file)
    if super != "" && mod != ""
      return "$super.$mod"
    else
      return super == "" ? mod : super
    end
  end
  return ""
end

const filemodule = memoize(filemodule_)

# Get all modules

children(m::Module) =
  @>> names(m, true) map(x->getthing(m, [x])) filter(x->isa(x, Module) && x ≠ m)

function allchildren(m::Module, cs = Set{Module}())
  for c in children(m)
    c in cs || (push!(cs, c); allchildren(c, cs))
  end
  return cs
end
