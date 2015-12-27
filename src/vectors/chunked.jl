export ChunkedVector

immutable ChunkedVector{T,A<:AVector,N} <: AVector{T}
  data::Vector{A}
end

typealias ChunkedVectorT{T,A,N} Type{ChunkedVector{T,A,N}}

call{T,A,N}(::ChunkedVectorT{T,A,N}, data = A[A()]) =
  ChunkedVector{T,A,N}(data)

call{T,A}(::ChunkedVectorT{T,A}, data = A[A()]) =
  ChunkedVector{T,A,128}(data)

call{T}(::ChunkedVectorT{T}, a...) =
  ChunkedVector{T,Vector{T}}(a...)

chunksize{T,A,N}(::Type{ChunkedVector{T,A,N}}) = N
chunksize(xs::ChunkedVector) = chunksize(typeof(xs))

chunks(xs::ChunkedVector) = xs.data

function makeroom!(xs::ChunkedVector)
  push!(xs.data, similar(xs.data[end], 0))
end

function Base.push!(xs::ChunkedVector, y)
  length(xs.data[end]) == chunksize(xs) && makeroom!(xs)
  push!(xs.data[end], y)
  return xs
end

function ChunkedVector(xs, a...)
  v = ChunkedVector{eltype(xs)}(a...)
  for x in xs
    push!(v, x)
  end
  return v
end

function index_slow(xs::ChunkedVector, i)
  j, i′ = divrem(i-1, chunksize(xs))
  j + 1, i′ + 1
end

@generated function index_fast(xs::ChunkedVector, i)
  pow = round(Int, log2(chunksize(xs)))
  :((i-1) >> $pow + 1, (i-1) & $(2^pow-1) + 1)
end

@generated function index(xs::ChunkedVector, i)
  ispow2(chunksize(xs)) ?
    :(index_fast(xs, i)) :
    :(index_slow(xs, i))
end

@inline function Base.getindex(xs::ChunkedVector, i::Integer)
  j, i′ = index(xs, i)
  @inbounds return xs.data[j][i′]
end

function Base.setindex!(xs::ChunkedVector, v, i::Integer)
  j, i′ = index(xs, i)
  @inbounds xs.data[j][i′] = v
end

Base.length(xs::ChunkedVector) = chunksize(xs)*(length(xs.data)-1)+length(xs.data[end])

Base.size(xs::ChunkedVector) = (length(xs),)

# Iteration utils

immutable ChunkIter{N}
  max::Tuple{Int,Int}
end

chunksize{N}(::Type{ChunkIter{N}}) = N
chunksize(it::ChunkIter) = chunksize(typeof(it))

Base.start(::ChunkIter) = (1, 0)

Base.done(it::ChunkIter, state) =
  state[2] == it.max[2] && state[1] == it.max[1]

@inline function _next(it::ChunkIter, last)
  i, j = last
  j == chunksize(it) ? (i+1, 1) : (i, j+1)
end

function Base.next(it::ChunkIter, last)
  next = _next(it, last)
  next, next
end

Base.length(it::ChunkIter) = (it.max[1]-1)*chunksize(it)+it.max[2]

# ChunkVector iteration

ChunkIter(xs::ChunkedVector) =
  ChunkIter{chunksize(xs)}((length(xs.data), length(xs.data[end])))

@iter xs::ChunkedVector -> ChunkIter(xs)

@inline function Base.next(xs::ChunkedVector, sub::SubIter)
  i, j = _next(sub.iter, sub.state)
  @inbounds return xs.data[i][j], SubIter(sub.iter, (i, j))
end
