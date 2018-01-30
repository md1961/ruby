require_relative 'test'

class Dictionary

  def initialize(words)
    @words = words
  end

  def find_most_similar(term)
    h_words_by_len_diff = @words.group_by { |word| (word.length - term.length).abs }
    result = nil
    min_changes = term.length
    h_words_by_len_diff.keys.sort.each do |len_diff|
      h_words_by_len_diff[len_diff].each do |word|
        num = num_changes(word, term)
        if num < min_changes
          result = word
          min_changes = num
        end
      end
      break if min_changes <= len_diff
    end
    result
  end

  private

    def num_changes(word1, word2)
      w1 = '-' + word1
      w2 = '-' + word2
      nums = Array.new(w1.length) { Array.new(w2.length) }
      w2.length.times do |j|
        nums[0][j] = j
      end
      w1.length.times do |i|
        nums[i][0] = i
      end
      (1 ... w1.length).each do |i|
        (1 ... w2.length).each do |j|
          nums[i][j] = \
            if w1[i] == w2[j]
              nums[i - 1][j - 1]
            else
              [nums[i - 1][j - 1], nums[i - 1][j], nums[i][j - 1]].min + 1
            end
        end
      end

      print_nums(nums, w1, w2)

      nums.last.last
    end

    # TODO: Remove print_nums() before submitting.
    def print_nums(nums, w1, w2)
      puts "  #{w2.chars.join(' ')}"
      w1.length.times do |i|
        print "#{w1[i]} "
        puts nums[i].map { |n| n.nil? ? '-' : n.to_s(16).upcase }.join(' ')
      end
    end
end


if __FILE__ == $0
  words = %w[cherry peach pineapple melon strawberry raspberry apple coconut banana]
  test_dict = Dictionary.new(words)
  Test.assert_equals(test_dict.find_most_similar('strawbery'),'strawberry')
  Test.assert_equals(test_dict.find_most_similar('berry'),'cherry')
  Test.assert_equals(test_dict.find_most_similar('aple'),'apple')
end
