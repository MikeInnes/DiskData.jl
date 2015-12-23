immutable CacheStack{T}
  size::Int
  stack::Vector{T}
end

typealias CacheStackT{T} Type{CacheStack{T}}

call{T}(::CacheStackT{T}, size = 1) = CacheStack{T}(size, T[])

function touch!{T}(c::CacheStack{T}, x::T)
  @assert c.size == 1
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

type CacheVector{T,A} <: AVector{T}
  cache::CacheStack{CacheVector{T,A}}
  data::A
  view::Vector{T}
  hash::UInt64
end

CacheVector(c::CacheStack, xs::AVector) =
  CacheVector(c, xs, eltype(xs)[], UInt64(0))

CacheVector{T,A}(c::CacheStack{CacheVector{T,A}}) = CacheVector(c, A())

isloaded(v::CacheVector) = v.hash ≠ 0

function load!(v::CacheVector)
  isloaded(v) && return v
  info("loading data")
  v.view = collect(v.data)
  v.hash = hash(v.view)
  return v
end

function store!(v::CacheVector)
  isloaded(v) || return v
  if hash(v.view) ≠ v.hash
    info("storing data")
    v.data[1:end] = slice(v.view, 1:endof(v.data))
    if length(v.view) > length(v.data)
      append!(v.data, slice(v.view, endof(v.data)+1:endof(v.view)))
    end
    # TODO: catch shortened arrays as well
  end
  v.view = []
  v.hash = 0
  return v
end

touch!(v::CacheVector) = touch!(v.cache, v)

for f in :[Base.getindex, Base.setindex!, Base.push!, Base.size].args
  @eval function $f(xs::CacheVector, args...)
    touch!(xs)
    $f(xs.view, args...)
  end
end

Base.similar(xs::CacheVector, args...) =
  CacheVector(xs.cache, similar(xs.data, args...))
