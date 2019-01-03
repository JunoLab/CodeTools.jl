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
  @as x dir readdir′(x) map!(f->joinpath(dir, f), x ,x) filter!(isfile′, x)

dirs(dir) =
  @as x dir readdir′(x) filter!(f->!startswith(f, "."), x) map!(f->joinpath(dir, f), x, x) filter!(isdir′, x)

jl_files(dir::AbstractString) = @>> dir files filter!(f->endswith(f, ".jl"))

function jl_files(set)
  files = Set{String}()
  for dir in set, file in jl_files(dir)
    push!(files, file)
  end
  return files
end

# Recursion + Mutable State = Job Security
"""
Takes a start directory and returns a set of nearby directories.
"""
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
  openers = [[0,0,0]]
  n_openers = 0
  n_brackets = 0
  n_parens = 0
  # index of next modulename token
  next_modulename = -1

  ts = tokenize(code)

  last_token = nothing

  for (i, t) in enumerate(ts)
    Tokens.startpos(t)[1] > line && break

    # Ignore everything in brackets or parnetheses, because any scope started in
    # them also needs to be closed in them. That way, we don't need special
    # handling for comprehensions and `end`-indexing.
    if Tokens.kind(t) == Tokens.LSQUARE
      openers[length(stack)+1][2] += 1
    elseif openers[length(stack)+1][2] > 0
      if Tokens.kind(t) == Tokens.RSQUARE
        openers[length(stack)+1][2] -= 1
      end
    elseif Tokens.kind(t) == Tokens.LPAREN
      openers[length(stack)+1][3] += 1
    elseif openers[length(stack)+1][3] > 0
      if Tokens.kind(t) == Tokens.RPAREN
        openers[length(stack)+1][3] -= 1
      end
    elseif Tokens.exactkind(t) in MODULE_STARTERS && (last_token == nothing || Tokens.kind(last_token) == Tokens.WHITESPACE) # new module
      next_modulename = i + 2
    elseif i == next_modulename && Tokens.kind(t) == Tokens.IDENTIFIER && Tokens.kind(last_token) == Tokens.WHITESPACE
      push!(stack, Tokens.untokenize(t))
      push!(openers, [0,0,0])
    elseif Tokens.exactkind(t) in SCOPE_STARTERS  # new non-module scope
      openers[length(stack)+1][1] += 1
    elseif Tokens.exactkind(t) == Tokens.END  # scope ended
      if openers[length(stack)+1][1] == 0
        !isempty(stack) && pop!(stack)
        length(openers) > 1 && pop!(openers)
      else
        openers[length(stack)+1][1] -= 1
      end
    end
    last_token = t
  end
  return join(stack, ".")
end

codemodule(code, pos::Cursor) = codemodule(code, pos.line)

"""
Takes a given Julia source file and another (absolute) path, gives the
line on which the path is included in the file or 0.
"""
function includeline(file::AbstractString, included_file::AbstractString)
  # check for erroneous self includes, doesn't detect more complex cycles though
  file == included_file && return 0

  line = 1
  tokens = Tokenize.tokenize(read(file, String))

  t, state = iterate(tokens)
  while true
    if Tokens.kind(t) == Tokens.WHITESPACE
      line += count(x -> x == '\n', t.val)
    elseif Tokens.kind(t) == Tokens.IDENTIFIER && t.val == "include"
      t, state = iterate(tokens, state)
      if Tokens.kind(t) == Tokens.LPAREN
        t, state = iterate(tokens, state)
        if Tokens.kind(t) == Tokens.STRING
          if normpath(joinpath(dirname(file), chop(t.val, head=1, tail=1))) == included_file
            return line
          end
        end
      end
    elseif Tokens.kind(t) == Tokens.ENDMARKER
      break
    end
    t, state = iterate(tokens, state)
  end
  return 0
end

"""
Takes an absolute path to a file and returns the (file, line) where that
file is included or nothing.
"""
function find_include(path::AbstractString)
  for file in @> path dirname dirsnearby jl_files
    line = -1
    try
      line = includeline(file, path)
    catch err
      return nothing
    end
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
    mod = codemodule(read(file, String), line)
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
function children(m::Module)
  return @>> [moduleusings(m); getmodule.(Ref(m), string.(_names(m, all=true, imported=true)))] filter(x->isa(x, Module) && x ≠ m) unique
end

function allchildren(m::Module, cs = Set{Module}())
  for c in children(m)
    c in cs || (push!(cs, c); allchildren(c, cs))
  end
  return cs
end
