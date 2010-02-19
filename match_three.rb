#! /usr/bin/env ruby

a = [1, 1, 3, 4]
b = [1, 1, 3, 4]

class MatchThree
  MASK = 1000
  IMPOSSIBLE_VALUE = -99999999

  def self.judge(a0, a1)
    aa0 = mask_array(a0)
    aa1 = mask_array(a1)
    h = Hash.new(0)
    (aa0 + aa1).each { |item|
      h[item] += 1
    }
    h_freq = Hash.new { |hash, key| hash[key] = Array.new }
    h.each { |masked_item, freq|
      item = masked_item % MASK
      h_freq[freq] << item
    }
    p h_freq
    puts "So the judge is '#{h_freq[2].size == 3}'."
  end

  private

    def self.mask_array(a)
      prev_item = IMPOSSIBLE_VALUE
      freq = 1
      new_a = Array.new
      a.each { |item|
        if item == prev_item
          freq += 1
        else
          freq = 1
        end
        new_a << item + MASK * freq
        prev_item = item
      }
      new_a
    end
end

MatchThree.judge(a, b)

