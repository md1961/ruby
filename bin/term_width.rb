#! /bin/env ruby
# vi: set fileencoding=utf-8 :

# 端末表示幅を計測するためのスクリプト

if ARGV.size != 1 || (n = ARGV[0].to_i) <= 0
  $stderr.puts "#{$0}: Specify one positive integer"
  exit
end

(n / 10).times do |i|
  s = ' ' * 9 + (i + 1).to_s
  print s[-10 .. -1]
end
puts

n.times do |i|
  print((i + 1) % 10)
end
puts

