export DiskVector

type DiskVector{T} <: AVector{T}
  length::Int
  file::UTF8String
  handle::IOStream
  pos::Int
end

typealias DiskVectorT{T} Type{DiskVector{T}}

function call{T}(::DiskVectorT{T})
  file = tempname()
  v = DiskVector{T}(0, file, open(file, "a+"), 1)
  finalizer(v, close)
  return v
end

function call{T}(::DiskVectorT{T}, xs)
  v = DiskVector{T}()
  for x in xs
    push!(v, x)
  end
  return v
end

DiskVector() = DiskVector{Any}()
DiskVector(xs) = DiskVector{eltype(xs)}(xs)

function Base.close(v::DiskVector)
  isopen(v.handle) && close(v.handle)
  isfile(v.file) && rm(v.file)
end

Base.size(v::DiskVector) = (v.length,)

function Base.push!{T}(v::DiskVector{T}, x::T)
  warn("pushing single value")
  seekto(v, :end)
  if isbits(T)
    write(v.handle, x)
  else
    serialize(v.handle, x)
  end
  v.length += 1
  v.pos += 1
  return v
end

function Base.append!{T}(v::DiskVector{T}, xs::AbstractVector{T})
  seekto(v, :end)
  @assert isbits(T)
  write(v.handle, xs)
  v.length += length(xs)
  v.pos = v.length+1
  return v
end

# The basic seek methods don't seem to be particularly smart about this, so we keep track of
# where we are to avoid file system calls
function seekto(v::DiskVector, i)
  @assert isbits(eltype(v))
  if i == :end
    if v.pos ≤ v.length
      seekend(v.handle)
      v.pos = v.length+1
    end
  elseif v.pos ≠ i
    v.pos = i
    seek(v.handle, sizeof(eltype(v))*(i-1))
  end
end

function Base.getindex(v::DiskVector, i::Integer)
  warn("reading single value")
  seekto(v, i)
  v.pos += 1
  return read(v.handle, eltype(v))
end

function Base.setindex!{T}(v::DiskVector{T}, x::T, i::Integer)
  warn("writing single value")
  seekto(v, i)
  write(v.handle, x)
  v.pos += 1
  return x
end

function Base.copy!{T}(v::AbstractVector{T}, xs::DiskVector{T})
  @assert isbits(T)
  seekstart(xs.handle)
  read!(xs.handle, v)
  return v
end

# Need the extra copy due to shared array data
Base.collect(xs::DiskVector) = copy(copy!(Vector{eltype(xs)}(length(xs)), xs))

function Base.similar(v::DiskVector, n::Integer)
  @assert n == 0
  DiskVector{eltype(v)}()
end

# Merge sort

function merge{T}(xs::AVector{T}, ys::AVector{T})
  v = DiskVector{T}()
  ix, iy = 1, 1
  nx, ny = length(xs), length(ys)
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

function Base.sort(xs::DiskVector)
  n = 5*10^8 # ~ 4 GB
  sort_mem(xs) = DiskVector(sort!(collect(xs)))
  if length(xs) ≤ n
    return sort_mem(xs)
  else
    left, right = slice(xs, 1:length(xs)÷2), slice(xs, length(xs)÷2+1:length(xs))
    if length(left) ≤ n
      return merge(sort_mem(left), sort_mem(right))
    else
      return merge(sort(DiskVector(left)), sort(DiskVector(right)))
    end
  end
end

# run(`open $(dirname(tempname()))`)
