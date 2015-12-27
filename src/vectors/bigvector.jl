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

@forward BigVector.data Base.size, Base.getindex, Base.setindex!, Base.push!, chunks

@iter xs::BigVector -> xs.data
