lines(s) = split(s, "\n")

function memoize(f)
  mem = d()
  (args...) -> Base.@get!(mem, args, f(args...))
end

function memoize_debounce(f, expiry = 1)
  mem = d()
  function (args...)
    if haskey(mem, args)
      result, t = mem[args]
      if t + expiry > time()
        mem[args] = result, time()
        return result
      end
    end
    result = f(args...)
    mem[args] = result, time()
    return result
  end
end

function withpath(f, path)
  tls = task_local_storage()
  hassource = haskey(tls, :SOURCE_PATH)
  hassource && (path′ = tls[:SOURCE_PATH])
  tls[:SOURCE_PATH] = path
  try
    return f()
  finally
    hassource ?
      (tls[:SOURCE_PATH] = path′) :
      delete!(tls, :SOURCE_PATH)
  end
end
