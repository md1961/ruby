$debug = 1

$h = {}

def n_patterns(total, n_pubs, max = nil)
  args = [total, n_pubs, max]

  print "n_patterns(#{args.join(', ')}): " if $debug
  puts "#{$h[args]} from cache" if $debug && $h[args]

  $h[args] || calc_n_patterns(*args).tap { |n|
    $h[args] = n

    puts n if $debug

  }
end

def calc_n_patterns(total, n_pubs, max)
  return 0 if n_pubs <= 0 || total < n_pubs || (max && total > max * n_pubs)
  return 1 if total == n_pubs
  case n_pubs
  when 1
    1
  when 2
    t0 = (total + 1) / 2
    t1 = [total - 1, max].compact.min
    (t0 .. t1).size
  else
    t0 = 1
    t1 = [total - (n_pubs - 1), max].compact.min
    (t0 .. t1).reduce(0) { |n_pats, first|
      next_max = [first, max].compact.min
      n_pats + n_patterns(total - first, n_pubs - 1, next_max)
    }
  end
end


def n_patterns_seq(total, n_pubs)
  count = 0
  (1 .. total - n_pubs + 1).to_a.reverse.repeated_permutation(n_pubs) do |pubs|
    if pubs.inject(:+) == total && pubs.sort.reverse == pubs
      count += 1
      p pubs
    end
  end
  count
end


def assert_equals(actual, expected)
  if actual == expected
    puts "OK"
  else
    puts "NG: expected #{expected}, got #{actual}"
  end
end

if __FILE__ == $0
  puts n_patterns_seq(10, 1 + 1)
  puts n_patterns_seq(10, 1 + 2)
  puts n_patterns_seq(10, 1 + 3)
  puts n_patterns_seq(20, 1 + 3)

  sum = 20
  count = 0
  while s = DATA.gets&.chomp do
    count += 1
    puts "#{s}: sum is not #{sum}" unless s.split.map(&:to_i).reduce(:+) == sum
  end
  puts "DATA count = #{count}"

  exit

  $debug = nil
  assert_equals(n_patterns(10, 1 + 1), 5)
  assert_equals(n_patterns(10, 1 + 2), 8)
  assert_equals(n_patterns(10, 1 + 3), 9)
  $debug = 1
  assert_equals(n_patterns(20, 1 + 3), 64)
  #assert_equals(n_patterns(100, 1 + 10), 4426616)
end


__END__
17  1  1  1
16  2  1  1
15  3  1  1
15  2  2  1
14  4  1  1
14  3  2  1
14  2  2  2
13  5  1  1
13  4  2  1
13  3  3  1
13  3  2  2
12  6  1  1
12  5  2  1
12  4  3  1
12  4  2  2
12  3  3  2
11  7  1  1
11  6  2  1
11  5  3  1
11  5  2  2
11  4  4  1
11  4  3  2
11  3  3  3
10  8  1  1
10  7  2  1
10  6  3  1
10  6  2  2
10  5  4  1
10  5  3  2
10  4  4  2
10  4  3  3
 9  9  1  1
 9  8  2  1
 9  7  3  1
 9  7  2  2
 9  6  4  1
 9  6  3  2
 9  5  5  1
 9  5  4  2
 9  5  3  3
 9  4  4  3
 8  8  3  1
 8  8  2  2
 8  7  4  1
 8  7  3  2
 8  6  5  1
 8  6  4  2
 8  6  3  3
 8  5  5  2
 8  5  4  3
 8  4  4  4
 7  7  5  1
 7  7  4  2
 7  7  3  3
 7  6  6  1
 7  6  5  2
 7  6  4  3
 7  5  5  3
 7  5  4  4
 6  6  6  2
 6  6  5  3
 6  6  4  4
 6  5  5  4
 5  5  5  5
