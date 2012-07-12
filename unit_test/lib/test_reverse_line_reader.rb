# vi: set fileencoding=utf-8 :

require 'test/unit'

require 'reverse_line_reader'
require 'stringio'


class TestReverseLineReader < Test::Unit::TestCase

  def test_empty_file
    data = ''
    actual_lines = read_lines_with_ReverseLineReader(data)

    assert_equal(0, actual_lines.size, "Number of lines")
  end

    def read_lines_with_ReverseLineReader(original_data)
      io = StringIO.new(original_data)
      lines = Array.new
      ReverseLineReader.new(io).each do |line|
        lines << line
      end
      return lines
    end
    private :read_lines_with_ReverseLineReader

  def test_one_line_file
    oneliner = "Just this line" + $/
    actual_lines = read_lines_with_ReverseLineReader(oneliner)

    assert_equal(1, actual_lines.size, "Number of lines")
    assert_equal(oneliner, actual_lines[0], "Line #01")
  end

  def test_multiple_line_file
    original_lines = [
      " 1: class Test",
      " 2:   def test",
      " 3:     # 何もしない",
      " 4:   end",
      " 5: end",
    ].map { |line| line + $/ }

    actual_lines = read_lines_with_ReverseLineReader(original_lines.join(''))

    assert_equal(original_lines.size, actual_lines.size, "Number of lines")
    assert_equal(original_lines.reverse, actual_lines, "Contents")
  end
end

