using MacroTools

# Forwarding iteration

macro iter(ex, it)
  @capture(ex, x_::T_) || error("Use @iter x::T ...")
  quote
    @inline function Base.start($x::$T)
      it = $it
      it, Base.start(it)
    end
    @inline function Base.next(::$T, sub)
      it, state = sub
      next, state = Base.next(it, state)
      next, (it, state)
    end
    @inline function Base.done(::$T, sub)
      it, state = sub
      it, state
      Base.done(it, state)
    end
  end |> esc
end

# Nested Iteration

immutable NestedIter{I}
  it::I
end

@inline function Base.start(i::NestedIter)
  state = start(i.it)
  @assert !done(i.it, state)
  sub, state = next(i.it, state)
  state, sub, start(sub)
end

@inline function Base.done(i::NestedIter, s)
  state, sub, substate = s
  done(sub, substate) && done(i.it, state)
end

@inline function Base.next(i::NestedIter, s)
  state, sub, substate = s
  if done(sub, substate)
    sub, state = next(i.it, state)
    substate = start(sub)
  end
  x, substate = next(sub, substate)
  x, (state, sub, substate)
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
