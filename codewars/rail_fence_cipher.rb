=begin

"WE ARE DISCOVERED. FLEE AT ONCE" would be mapped to
a three rail system as follows
(omitting punctuation and spaces):

0       4       8
W . . . E . . . C . . . R . . . L . . . T . . . E
. E . R . D . S . O . E . E . F . E . A . O . C .
. . A . . . I . . . V . . . D . . . E . . . N . .
    2       6      10

((n - 1) * 2) cycle
cycles, rests = t / (n - 1) /% 2

cycles % 2 == 0 -> down, 1 -> up

down cycle => rails[0] .. rails[n-2]
  up cycle => rails[n-1] .. rails[1]


0           2n-2
 1
  2
   3     1
    .   0
     n-1
The encoded string would be:

WECRLTEERDSOEEFEAOCAIVDEN

=end

def encode_rail_fence_cipher(str, num_rails)
  rails = Array.new(num_rails) { [] }
  i_rail = rail_index(num_rails)
  str.each_char.with_index do |c, i|
    rails[i_rail.next][i] = c
  end
  rails.map(&:compact).map(&:join).join
end

def decode_rail_fence_cipher(str, num_rails)
  length = str.length
  n_cycles, n_rest = length .divmod (num_rails - 1)
  n_chars = [n_cycles / 2] + [n_cycles] * (num_rails - 2) + [n_cycles / 2]
  n_chars[0] += 1 if n_cycles % 2 == 1
  i_range_rest = n_cycles % 2 == 0 ? (0 .. n_rest - 1) : (num_rails - n_rest .. num_rails - 1)
  i_range_rest.each { |i| n_chars[i] += 1 }
  chars = str.chars
  rails = n_chars.reduce([]) { |result, n_char| result << chars.shift(n_char) }
  i_rail = rail_index(num_rails)
  result = []
  while !rails.all?(&:empty?) do
    result << rails[i_rail.next].shift
  end
  result.join
end

def rail_index(num_rails)
  is_increasing = true
  index = 0
  Enumerator.new do |indexes|
    loop do
      indexes << index
      if index.zero? && !is_increasing
        is_increasing = true
      elsif index == num_rails - 1
        is_increasing = false
      end
      index += is_increasing ? 1 : -1
    end
  end
end


if __FILE__ == $0
  num_rails = 5
  length = 100
  chars = ('a'..'z').to_a
  s = 100.times.map { chars.sample }.join
  encoded = encode_rail_fence_cipher(s, num_rails)
  actual = decode_rail_fence_cipher(encoded, num_rails)
  expected = s

  puts encoded
  puts actual
  puts expected
  puts actual == expected

  exit

  s = "WE ARE DISCOVERED. FLEE AT ONCE".delete(' .')
  actual = encode_rail_fence_cipher(s, 3)
  expected = "WECRLTEERDSOEEFEAOCAIVDEN"

  puts actual
  puts expected
  puts actual == expected

  s, expected = expected, s
  actual = decode_rail_fence_cipher(s, 3)

  puts actual
  puts expected
  puts actual == expected
end
