def move(from, to)
  "#{from} #{to}"
end

def moves(n, from, to)
  raise "n must be > 0 (#{n} given)" if n < 1
  return [move(from, to)] if n == 1
  tmp = 'ABC'.sub(from.to_s, '').sub(to.to_s, '').to_sym
  moves(n - 1, from, tmp) + [move(from, to)] + moves(n - 1, tmp, to)
end


if __FILE__ == $0
  n, t = gets.split.map(&:to_i)

  h = {A: (1 .. n).to_a.reverse, B: [], C: []}
  moves(n, :A, :C)[0 .. t - 1].each do |move|
    from, to = move.split.map(&:to_sym)
    h[to] << h[from].pop
  end

  %i[A B C].each do |k|
    v = h[k]
    puts v.empty? ? '-' : v.join(' ')
  end
end
