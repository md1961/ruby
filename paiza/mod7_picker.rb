def multiple(from, to = 1)
  from, to = to, from if from > to
  (from .. to).reduce { |m, i| m * i }
end

def n_combinations(n, k)
  multiple(n, n - k + 1) / multiple(k)
end


$stdin = DATA


n = gets.to_i
h = Hash.new(0)
n.times do
  a = gets.to_i
  h[a % 7] += 1
end

puts (0 .. 6).to_a.repeated_combination(3).map { |(*a)|
  a.uniq.map { |e| [e, a.count(e)] }.to_h if a.sum % 7 == 0
}.compact.reduce(0) { |s, h_count|
  s + h_count.reduce(1) { |acc, (n, count)| acc * n_combinations(h[n], count) }
}


__END__
14
937
183
0
574
38
982
1833
74
1901
210
84
37
284
565
