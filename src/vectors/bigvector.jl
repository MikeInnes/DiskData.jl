immutable CacheChunkVector{T,A,N} <: AbstractVector{T}
  cache::CacheStack{CacheVector{T,A}}
  data::ChunkedVector{T,CacheVector{T,A},N}
end

function call{T,A,N}(::Type{CacheChunkVector{T,A,N}})
  cache = CacheStack{CacheVector{T,A}}()
  data = ChunkedVector{T,CacheVector{T,A},N}(CacheVector{T,A}[CacheVector(cache, A())])
  CacheChunkVector{T,A,N}(cache, data)
end

@forward CacheChunkVector.data Base.size, Base.getindex, Base.setindex!, Base.push!,
  ChunkIter, chunks

@iter xs::CacheChunkVector -> ChunkIter(xs)

function Base.start(xs::CacheChunkVector)
  it = ChunkIter(xs)
  touch!(chunks(xs)[1])
  return SubIter(it, start(it))
end

@inline function Base.next(xs::CacheChunkVector, sub::SubIter)
  i, j = sub.state
  if j == chunksize(sub.iter)
    i, j = i+1, 1
    @inbounds touch!(chunks(xs)[i])
  else
    i, j = i, j+1
  end
  @inbounds return chunks(xs)[i].view[j], SubIter(sub.iter, (i, j))
end

# Convenience Alias

export BigVector

immutable BigVector{T,N} <: AVector{T}
  data::CacheChunkVector{T,DiskVector{T},N}
end

call{T}(::Type{BigVector{T}}, chunk::Integer = prevpow2(150*1024^2÷sizeof(T))) =
  BigVector{T,chunk}(CacheChunkVector{T,DiskVector{T},chunk}())

function BigVector(xs)
  v = BigVector{eltype(xs)}()
  for x in xs push!(v, x) end
  return v
end

@forward BigVector.data Base.size, Base.getindex, Base.setindex!, Base.push!, chunks

@iter xs::BigVector -> xs.data

# Merge sort

function merge{T}(xs::AVector{T}, ys::AVector{T})
  v = BigVector{T}()
  ix, nx, iy, ny = 1, length(xs), 1, length(ys)
  while true
    if ix ≤ nx && (iy > ny || xs[ix] ≤ ys[iy])
      push!(v, xs[ix])
      ix += 1
    elseif iy ≤ ny && (ix > nx || ys[iy] ≤ xs[ix])
      push!(v, ys[iy])
      iy += 1
    else
      break
    end
  end
  return v
end

function sort_mem(xs)
  ys = BigVector(sort!(copy(xs)))
  gc()
  return ys
end

function Base.sort(xs::BigVector)
  n = 4*1024^3÷sizeof(eltype(xs))
  if length(xs) ≤ n
    return sort_mem(xs)
  else
    left, right = slice(xs, 1:length(xs)÷2), slice(xs, length(xs)÷2+1:length(xs))
    if length(left) ≤ n
      return merge(sort_mem(left), sort_mem(right))
    else
      return merge(sort(BigVector(left)), sort(BigVector(right)))
    end
  end
end
