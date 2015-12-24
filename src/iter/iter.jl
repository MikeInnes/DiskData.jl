using MacroTools

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
