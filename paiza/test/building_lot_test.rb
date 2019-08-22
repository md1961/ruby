require 'test-unit'
require 'stringio'

require_relative '../building_lot'


class BuildingLotTest < Test::Unit::TestCase

  def test_case_01
    input = <<-END
      5 5 2
      2 5 2 2
      2 5 1 3
    END

    expected = <<-END
      1 1 1 1 1
      1 1 1 1 1
      . + + . .
      2 2 2 2 2
      2 2 2 2 2
    END

    do_test(input, expected)
  end

  def test_case_02
    input = <<-END
      5 7 4
      3 5 3 3
      3 5 2 1
      3 5 2 5
      3 5 1 3
    END

    expected = <<-END
      1 1 1 1 1 . .
      1 1 1 1 1 . .
      1 1 1 1 1 . .
      . . + . . . .
      . . . . . . .
    END

    do_test(input, expected)
  end

  def test_case_03
    input = <<-END
      6 7 3
      2 4 2 3
      2 5 2 3
      3 2 2 1
    END

    expected = <<-END
      2 2 2 2 2 . .
      2 2 2 2 2 3 3
      . . + . + 3 3
      1 1 1 1 . 3 3
      1 1 1 1 . . .
      . . + . . . .
    END

    do_test(input, expected)
  end

  private

    def do_test(input, expected)
      allocator = Allocator.build_from(input)
      allocator.allocate
      assert_equal(expected.gsub(/^\s*/, '').chomp, allocator.to_s(:pretty))
    end
end
