#! /bin/env ruby

# Place 10 bowling pins numbered from 1 to 10 like in games.
# How many placements makes the sums of four numbers on three sides
# all equal?
#
# In the placement below, total of three sides are all 24.
#
#   10   6   3   5
#      9   2   7
#        1   8
#          4

def good?(pins)
  raise "pins#size must be 9 (#{pins.size} given)" if pins.size != 9
  pins << pins[0]
  pins[0 .. 3].inject(&:+) == pins[3 .. 6].inject(&:+) && \
  pins[0 .. 3].inject(&:+) == pins[6 .. 9].inject(&:+)
end

#puts good?([10, 9, 1, 4, 8, 7, 5, 3, 6])

def all_seq(pins)
  return [pins] if pins.size <= 1
  return [pins, [pins[1], pins[0]]] if pins.size == 2
  retval = []
  pins.size.times do |i|
    _pins = pins.dup
    pin = _pins.delete_at(i)
    retval += all_seq(_pins).map { |x| [pin] + x }
  end
  retval
end

count = 0

(1 .. 10).to_a.each do |pin_exclude|
  pins = (1 .. 10).to_a
  pins.delete(pin_exclude)

  sub_count = 0
  #all_seq(pins).each do |_pins|
  pins.permutation.each do |_pins|
    sub_count += 1 if good?(_pins)
  end
  puts "Excluding '%2d': %d" % [pin_exclude, sub_count]
  count += sub_count
end

puts count
