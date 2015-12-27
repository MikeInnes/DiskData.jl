using MacroTools

# Forwarding iteration

immutable SubIter{I,S}
  iter::I
  state::S
end

macro iter(ex)
  @capture(ex, x_::T_ -> it_) || error("Use @iter x::T -> y ...")
  @capture(it, $x.f_) &&
    return :(@forward $(esc(T)).$f Base.start, Base.next, Base.done)
  quote
    @inline function Base.start($x::$T)
      it = $it
      SubIter(it, Base.start(it))
    end
    @inline function Base.next(::$T, sub::SubIter)
      next, state = Base.next(sub.iter, sub.state)
      next, SubIter(sub.iter, state)
    end
    @inline function Base.done(::$T, sub::SubIter)
      Base.done(sub.iter, sub.state)
    end
  end |> esc
end

# Lazy Map

immutable Map{F,T}
  f::F
  xs::T
end

@forward Map.xs Base.start, Base.done

function Base.next(m::Map, state)
  x, state = next(m.xs, state)
  return m.f(x), state
end

# Test

# export VecRef
#
# immutable VecRef{T}
#   x::T
# end
#
# @inline Base.start(x::VecRef, a...) = Base.start(x.x, a...)
# @inline Base.next(x::VecRef, a...) = Base.next(x.x, a...)
# @inline Base.done(x::VecRef, a...) = Base.done(x.x, a...)
#
# export VecRef2
#
# immutable VecRef2{T}
#   x::T
# end
#
# @iter x::VecRef2 -> x.x
