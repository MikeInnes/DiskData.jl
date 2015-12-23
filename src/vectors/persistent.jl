# Utils

append(a::Array, xs...) = push!(copy(a), xs...)

# DigitTries

type DigitTrie{T,R}
  depth::Int
  children::Vector{DigitTrie{T,R}}
  values::Vector{T}
  DigitTrie() = new(1)
end

typealias DigitTrieT{B<:DigitTrie} Type{B}

Base.eltype{T,R}(::Type{DigitTrie{T,R}}) = T
Base.eltype(t::DigitTrie) = eltype(typeof(t))

radix{T,R}(::Type{DigitTrie{T,R}}) = R
radix(t::DigitTrie) = radix(typeof(t))

function node(B::DigitTrieT, children)
  t = B()
  t.depth = 1 + children[1].depth
  t.children = children
  return t
end

function leaf(B::DigitTrieT, values)
  t = B()
  t.values = values
  return t
end

depth(t::DigitTrie) = t.depth

isleaf(t::DigitTrie) = depth(t) == 1

nest(t::DigitTrie, n) = reduce((t, _) -> node(typeof(t), [t]), t, 1:n)

function isfull(t::DigitTrie)
  if isleaf(t)
    length(t.values) == radix(t)
  else
    length(t.children) == radix(t) && isfull(t.children[end])
  end
end

function append(t::DigitTrie, x)
  if isfull(t)
    append(node(typeof(t), [t]), x)
  elseif isleaf(t)
    leaf(typeof(t), append(t.values, x))
  else
    children = copy(t.children)
    if isfull(children[end])
      push!(children, nest(leaf(typeof(t), [x]), depth(t)-2))
    else
      children[end] = append(children[end], x)
    end
    node(typeof(t), children)
  end
end

# Display/Debug

function Base.show(io::IO, t::DigitTrie)
  print(io, isleaf(t) ? "Leaf" : "Node")
  print(io, "::DigitTrie(")
  print_joined(io, isleaf(t) ? t.values : t.children, ",")
  print(io, ")")
end

# function treedump(io::IO, t::DigitTrie, indent=0)
#   println(io, "  "^indent, isleaf(t) ? "Leaf" : "Node")
#   if isleaf(t)
#     print(io, "  "^(indent+1))
#     print_joined(io, t.values, ", ")
#     println(io)
#   else
#     for c in t.children
#       treedump(io, c, indent+1)
#     end
#     for _ in 1:radix(t)-length(t.children)
#       println(io, "  "^(indent+1), "Empty")
#     end
#   end
# end
#
# treedump(t::DigitTrie) = treedump(STDOUT, t, indent)
#
# ctreedump(t::DigitTrie) = sprint(treedump, t) |> clipboard

function getindex_basic(t::DigitTrie, i::Integer)
  if isleaf(t)
    t.values[i]
  else
    childsize = radix(t)^(depth(t)-1)
    child, i′ = divrem(i-1, childsize)
    child += 1; i′ += 1
    getindex_basic(t.children[child], i′)
  end
end

@generated function getindex_fast(t::DigitTrie, i::Integer)
  r = radix(t)
  bits = round(Int, log2(r))
  mask = r - 1
  quote
    node = t
    shift = $bits*(depth(t)-1)
    for level = shift:-$bits:1
      node = node.children[((i-1)>>>level) & $mask + 1]
    end
    return node.values[(i - 1) & $mask + 1]
  end
end

@generated function Base.getindex(t::DigitTrie, i::Integer)
  if ispow2(radix(t))
    :(getindex_fast(t, i))
  else
    :(getindex_basic(t, i))
  end
end

# Tests

# l = leaf(DigitTrie{Int,32}, [])
#
# t = reduce(append, l, 1:100)
