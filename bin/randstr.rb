#! /bin/env ruby

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

srand

source = ""
(('a' .. 'z').to_a + ('0' .. '9').to_a).each do |c|
  source += c
end

result = ""
len.times do |i|
  result += source[(rand * source.length).to_i, 1]
end

puts "Generated random string: '#{result}'"

