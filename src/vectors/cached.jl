immutable CacheStack{T}
  size::Int
  stack::Vector{T}
end

typealias CacheStackT{T} Type{CacheStack{T}}

call{T}(::CacheStackT{T}, size = 1) = CacheStack{T}(size, T[])

function touch!{T}(c::CacheStack{T}, x::T)
  if isempty(c.stack)
    push!(c.stack, x)
  elseif c.stack[1] === x
    return x
  else
    store!(c.stack[1])
    c.stack[1] = x
  end
  return load!(x)
end

@enum CacheState Stored Loaded Modified

type CacheVector{T,A} <: AVector{T}
  cache::CacheStack{CacheVector{T,A}}
  data::A
  view::Vector{T}
  state::CacheState
end

CacheVector(c::CacheStack, xs::AVector) =
  CacheVector(c, xs, eltype(xs)[], Stored)

CacheVector{T,A}(c::CacheStack{CacheVector{T,A}}) = CacheVector(c, A())

isloaded(v::CacheVector) = v.state ≠ Stored

function load!(v::CacheVector)
  isloaded(v) && return v
  info("loading data")
  v.view = collect(v.data)
  v.state = Loaded
  return v
end

function store!(v::CacheVector)
  isloaded(v) || return v
  if v.state == Modified
    info("storing data")
    v.data[1:end] = slice(v.view, 1:endof(v.data))
    if length(v.view) > length(v.data)
      append!(v.data, slice(v.view, endof(v.data)+1:endof(v.view)))
    end
    # TODO: catch shortened arrays as well
  end
  v.view = []
  v.state = Stored
  return v
end

touch!(v::CacheVector) = touch!(v.cache, v)

for f in :[Base.getindex, Base.size].args
  @eval @inline function $f(xs::CacheVector, args...)
    touch!(xs)
    $f(xs.view, args...)
  end
end

for f in :[Base.setindex!, Base.push!].args
  @eval @inline function $f(xs::CacheVector, args...)
    touch!(xs)
    xs.state = Modified
    $f(xs.view, args...)
  end
end

Base.similar(xs::CacheVector, args...) =
  CacheVector(xs.cache, similar(xs.data, args...))
