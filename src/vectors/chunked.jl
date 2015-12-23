immutable ChunkedVector{T,A<:AVector} <: AVector{T}
  size::Int
  data::Vector{A}
end

typealias ChunkedVectorT{T,A} Type{ChunkedVector{T,A}}

call{T,A}(::ChunkedVectorT{T,A}, size = 128, data = A[A()]) =
  ChunkedVector{T,A}(size, data)

call{T}(::ChunkedVectorT{T}, a...) = ChunkedVector{T,Vector{T}}(a...)

function makeroom!(xs::ChunkedVector)
  push!(xs.data, similar(xs.data[end], 0))
end

function Base.push!(xs::ChunkedVector, y)
  length(xs.data[end]) == xs.size && makeroom!(xs)
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
  j, i′ = divrem(i-1, xs.size)
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

Base.length(xs::ChunkedVector) = xs.size*(length(xs.data)-1)+length(xs.data[end])

Base.size(xs::ChunkedVector) = (length(xs),)
