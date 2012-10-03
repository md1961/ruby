module Kaprekar

  module_function

  def kaprekar1?(n)
    n_sqr = n ** 2
    num_digits = (Math.log10(n_sqr) + 1).floor
    division = 10 ** (num_digits / 2.0).ceil
    n_upper, n_lower = n_sqr.divmod(division)
    n == n_upper + n_lower
  end

  def kaprekar2(n)
    digits = []
    while n > 0
      n, mod = n.divmod(10)
      digits << mod
    end
    min = digits.sort        .inject(0) { |s, n| s *= 10; s + n }
    max = digits.sort.reverse.inject(0) { |s, n| s *= 10; s + n }
    max - min
  end
end


if __FILE__ == $0
  puts "Kaprekar Numbers (Definition #1):"
  (1 .. 10000).each do |n|
    print n, ' ' if Kaprekar.kaprekar1?(n)
  end
  puts

  puts "Kaprekar Numbers (Definition #2):"
  (0 .. 99999).each do |n|
    kap2 = Kaprekar.kaprekar2(n)
    print n, ' ' if kap2 == n
  end
  puts
end

