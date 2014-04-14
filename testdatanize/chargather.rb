#! /usr/local/bin/ruby

field_number = Integer(ARGV[0])
pattern_to_gather = ARGV[1] || '.'

results = []
while STDIN.gets
  fields = $_.chomp.split("\t")
  fields[field_number].split(//).each do |char|
    results << char if char =~ /#{pattern_to_gather}/
  end
end

puts results.sort.uniq.join

