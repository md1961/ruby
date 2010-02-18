
class Test

  def self.add(x, y)
    return x + y;
  end

  def self.calc(x, y)
    result = add(x, y)
    puts "x = #{x}, y = #{y}, x + y = #{result}"
  end
end

if __FILE__ == $0
  if ARGV.size != 2
    puts "Specifiy two numbers"
    exit(1)
  end

  a = ARGV[0].to_f
  b = ARGV[1].to_f
  Test.calc(a, b)
end

