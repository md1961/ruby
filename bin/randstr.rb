#! /bin/env ruby
# vi: set fileencoding=utf-8 :

# 英子文字と数字からならランダムな文字列を生成するスクリプト

if ARGV.length != 1
  puts "Specify length of random string"
  exit
end

begin
  len = Integer(ARGV[0])
rescue ArgumentError
  puts "Specify an integer greater or equal to 1 ('#{ARGV[0]}' given)"
  exit
end

# Make a string which consists of [a-z0-9]
source = ""
(('a' .. 'z').to_a + ('0' .. '9').to_a).each do |c|
  source += c
end

srand

result = ""
len.times do |i|
  result += source[(rand * source.length).to_i, 1]
end

puts "Generated random string: '#{result}'"

