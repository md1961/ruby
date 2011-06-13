module FiberUsage

  module_function

  def counter(start=0)
    n = start

    return Fiber.new do
      loop do
        Fiber.yield n
        n += 1
      end
    end
  end

  def fibonacci
    return Fiber.new do
      last2 = 0
      Fiber.yield last2
      last  = 1
      Fiber.yield last
      loop do
        now = last2 + last
        Fiber.yield now
        last2, last = last, now
      end
    end
  end
end

module Recursive

  module_function

  def fibonacci(n)
    return 0 if n == 0
    return 1 if n == 1
    return fibonacci(n - 2) + fibonacci(n - 1)
  end
end


def measure_exec_time(title, &block)
  puts "===> #{title} <==="
  puts
  exec_times = Benchmark.measure(&block)
  puts
  puts Benchmark::CAPTION
  puts exec_times
end


if __FILE__ == $0
  require 'benchmark'

  if ARGV.size <= 0 || 1 < ARGV.size
    $stderr.puts "Usage: #{$0} num_outputs [start]"
    exit
  end

  num   = ARGV[0].to_i
  start = ARGV[1].to_i

  measure_exec_time("Using Fiber") {
    counter   = FiberUsage.counter(start)
    fibonacci = FiberUsage.fibonacci
    puts "count  Fibonacci"
    num.times do
      puts "%5d %10d" % [counter.resume, fibonacci.resume]
    end
  }

  puts
  puts

  measure_exec_time("Using a recusive call") {
    print "fibonacci(#{num - 1}) = "
    puts Recursive.fibonacci(num - 1)
  }
end

