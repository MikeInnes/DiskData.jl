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
