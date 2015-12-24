module DiskData

using Lazy

typealias AVector AbstractVector

include("iter/split.jl")
include("vectors/chunked.jl")
include("vectors/cached.jl")
include("vectors/disk.jl")
include("vectors/bigvector.jl")

end # module
