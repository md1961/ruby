$debug = false

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
    t1 = total - (n_pubs - 1)
    (t0 .. t1).reduce(0) { |n_pats, first|
      next_max = [first, max].compact.min
      n_pats + n_patterns(total - first, n_pubs - 1, next_max)
    }
  end
end


def assert_equals(actual, expected)
  if actual == expected
    puts "OK"
  else
    puts "NG: expected #{expected}, got #{actual}"
  end
end

if __FILE__ == $0
  assert_equals(n_patterns(10, 1 + 1), 5)
  assert_equals(n_patterns(10, 1 + 2), 8)
  assert_equals(n_patterns(100, 1 + 10), 2975338070)
end
