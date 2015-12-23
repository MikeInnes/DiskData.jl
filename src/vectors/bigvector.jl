immutable CacheChunkVector{T,A} <: AbstractVector{T}
  cache::CacheStack{CacheVector{T,A}}
  data::ChunkedVector{T,CacheVector{T,A}}
end

function call{T,A}(::Type{CacheChunkVector{T,A}}, size = 128)
  cache = CacheStack{CacheVector{T,A}}()
  data = ChunkedVector{T,CacheVector{T,A}}(size, CacheVector{T,A}[CacheVector(cache, A())])
  CacheChunkVector{T,A}(cache, data)
end

@forward CacheChunkVector.data Base.size, Base.getindex, Base.setindex!, Base.push!

export BigVector

immutable BigVector{T} <: AVector{T}
  data::CacheChunkVector{T,DiskVector{T}}
end

call{T}(::Type{BigVector{T}}, chunk::Integer = prevpow2(150*1024^2÷sizeof(T))) =
  BigVector{T}(CacheChunkVector{T,DiskVector{T}}(chunk))

@forward BigVector.data Base.size, Base.getindex, Base.setindex!, Base.push!
