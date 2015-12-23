export DiskVector

type DiskVector{T} <: AVector{T}
  cache::CacheGroup
  data::ChunkedVector{T,CacheVector{T}}
end

typealias DiskVectorT{T} Type{DiskVector{T}}

const BLOCK_SIZE = 1024^2 # bytes

function call{T}(::DiskVectorT{T})
  cache = CacheGroup{CacheVector{T},Vector{T}}()
  data = ChunkedVector{T,CacheVector{T}}(BLOCK_SIZE÷8, CacheVector{T}[CacheVector{T}(cache)])
  DiskVector(cache, data)
end

@forward DiskVector.data Base.push!, Base.length, Base.size, Base.getindex, Base.setindex!

function call{T}(::DiskVectorT{T}, xs)
  v = DiskVector{T}()
  for x in xs
    push!(v, x)
  end
  return v
end

DiskVector(xs) = DiskVector{eltype(xs)}(xs)

# map(iscached, xs.data.data) |> sum
