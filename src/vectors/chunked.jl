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

chunksize{T,A,N}(::ChunkedVector{T,A,N}) = N

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

function index(xs::ChunkedVector, i)
  j, i′ = divrem(i-1, chunksize(xs))
  j + 1, i′ + 1
end

function Base.getindex(xs::ChunkedVector, i::Integer)
  j, i′ = index(xs, i)
  xs.data[j][i′]
end

function Base.setindex!(xs::ChunkedVector, v, i::Integer)
  j, i′ = index(xs, i)
  xs.data[j][i′] = v
end

Base.length(xs::ChunkedVector) = chunksize(xs)*(length(xs.data)-1)+length(xs.data[end])

Base.size(xs::ChunkedVector) = (length(xs),)
