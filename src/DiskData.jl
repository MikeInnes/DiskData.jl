module DiskData

using Lazy

typealias AVector AbstractVector

include("vectors/chunked.jl")
include("vectors/cached.jl")
include("vectors/disk.jl")
include("vectors/bigvector.jl")
include("iter.jl")

end # module
