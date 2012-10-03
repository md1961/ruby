module Kaprekar

  module_function

  def kaprekar1?(n)
    n_sqr = n ** 2
    num_digits = (Math.log10(n_sqr) + 1).floor
    division = 10 ** (num_digits / 2.0).ceil
    n_upper, n_lower = n_sqr.divmod division
    n == n_upper + n_lower
  end
end


if __FILE__ == $0
  (1 .. 10000).each do |n|
    puts n if Kaprekar.kaprekar1?(n)
  end
end

