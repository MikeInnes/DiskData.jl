import Base: start, next, done
export aggregate

type Circle{T}
  xs::Vector{T}
  curr::Int
end

Circle(xs) = Circle(xs, 0)
(::Type{Circle{T}}){T}() = Circle(T[])

@forward Circle.xs Base.first, Base.last, Base.getindex, Base.push!

function next!(x::Circle)
  x.curr == length(x.xs) ?
    (x.curr = 1) :
    (x.curr += 1)
  return x.xs[x.curr]
end

type Spliterator{T, S, I}
  iter::T
  state::S
  chunk::I
  tasks::Circle{Task}
end

function Spliterator(iter)
  sub, state = chunk(iter, start(iter))
  s = Spliterator(iter, state, sub, Circle{Task}())
end

chunk(xs, state) =
  isempty(xs) ?
    (eltype(xs)[], 1):
    (eltype(xs)[xs[state]], state+1)

chunk!(s::Spliterator) =
  s.chunk, s.state = chunk(s.iter, s.state)

function next!(s::Spliterator)
  yieldto(next!(s.tasks))
  first(s.tasks) === current_task() && chunk!(s)
  return next(s.chunk, start(s.chunk))
end

start(s::Spliterator) = start(s.chunk)

done(s::Spliterator, state) =
  done(s.chunk, state) && done(s.iter, s.state)

next(s::Spliterator, state) =
  !done(s.chunk, state) ? next(s.chunk, state) : next!(s)

function splittask(xs::Spliterator, f, results)
  t = current_task()
  Task() do
    push!(results, f(xs))
    yieldto(last(xs.tasks) ≠ current_task() ? next!(xs.tasks) : t)
  end
end

function aggregate(xs, fs::Function...)
  xs = Spliterator(xs)
  results = []
  for f in fs
    push!(xs.tasks, splittask(xs, f, results))
  end
  yieldto(next!(xs.tasks))
  return results
end

function observer(id)
  function (xs)
    for x in xs
      println("$id sees $x")
    end
    return id
  end
end

# chunk(xs::Array, state) = xs, length(xs) + 1

# aggregate([:a, :b, :c], observer(1), observer(2))
#
# xs = collect(1:10^8)
#
# @time mean(xs)
# @time var(xs)
#
# @time aggregate(xs, mean, var)
