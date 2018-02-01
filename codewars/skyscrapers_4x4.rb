NORTH = :north
SOUTH = :south
EAST  = :east
WEST  = :west
ALL_SIDES = [NORTH, EAST, SOUTH, WEST]

def solve_puzzle(clues)
  heights = Array.new(4) { Array.new(4) { '1234' } }

  ALL_SIDES.cycle do |side|
    heights = use_clues_on(side, clues_on(side, clues), heights)

    print_heights(heights)

    break if solved?(heights)
  end

  heights.map { |row| row.map(&:to_i) }
end

def solved?(heights)
  heights.flatten.all? { |h| h.size == 1 }
end

def clues_on(side, clues)
  case side
  when NORTH
    clues[ 0, 4]        
  when EAST 
    clues[ 4, 4]        
  when SOUTH
    clues[ 8, 4].reverse
  when WEST 
    clues[12, 4].reverse
  end
end

  def print_heights(heights, side = nil, clues_for_side = [])
    puts side.to_s.upcase
    4.times do |i|
      puts "#{clues_for_side[i]} : #{heights[i].map { |h| h.center(4) }.join(' ')}"
    end
  end

def use_clues_on(side, clues_for_side, heights)
  rotated_heights = rotate_target_side_to_left(side, heights)
  clues_for_side.zip(rotated_heights) do |clue, row|
    case clue
    when 1
      decide_height('4', row, 0)
    when 2
      remove_possibility_for('4', row, 0)
      if !row[2].index('4') && !row[3].index('4') 
        decide_height('4', row, 1)
      elsif row[2] == '4' || row[3] == '4'
        decide_height('3', row, 0)
      end
    when 3
      remove_possibility_for('34', row, 0)
      remove_possibility_for( '4', row, 1)
      if row[3] == '4'
        if row[2] == '3'
          decide_height('2', row, 0)
          decide_height('1', row, 1)
        elsif !row[2].index('3')
          decide_height('3', row, 1)
        end
      elsif row[2] == '4'
        max1 = row[1].split('').max
        remove_possibility_for((max1 .. '3').to_a.join, row, 0)
      end
    when 4
      row = ('1' .. '4').to_a
    end

    print_heights(rotated_heights, side, clues_for_side)

  end
  restore_rotation(side, rotated_heights)
end

def decide_height(height, row, index)
  row[index] = height
  remove_other_possibilities_than(index, row)
end

def remove_possibility_for(height, row, index)
  cell_after = row[index].delete!(height)

  if cell_after && row[index].size == 0
    raise RuntimeError, "row = #{row.inspect}, index = #{index}, height = #{height}"
  end

  if cell_after && row[index].size == 1
    remove_other_possibilities_than(index, row)
  end
end

def remove_other_possibilities_than(index, row)
  row.size.times do |i|
    next if i == index
    remove_possibility_for(row[index], row, i)
  end
  confirm_sole_possibility(row)
end

def confirm_sole_possibility(row)
  ('1' .. '4').each do |h|
    if row.one? { |cell| cell.index(h) }
      i = row.index { |cell| cell.index(h) }
      row[i] = h
    end
  end
end

def rotate_target_side_to_left(side, heights)
  case side
  when WEST
    heights
  when NORTH
    heights.transpose
  when EAST
    heights.map(&:reverse)
  when SOUTH
    heights.transpose.map(&:reverse)
  end
end

def restore_rotation(side, heights)
  if side == SOUTH
    heights.map(&:reverse).transpose
  else
    rotate_target_side_to_left(side, heights)
  end
end

# TODO: Replace examples and use TDD development by writing your own tests
# These are some of the methods available:
#   Test.expect(boolean, [optional] message)
#   Test.assert_equals(actual, expected, [optional] message)
#   Test.assert_not_equals(actual, expected, [optional] message)

if __FILE__ == $0
  require_relative 'test'

  describe "Skyscrapers" do
    it "can solve 4x4 puzzle 1" do
      clues    = [ 2, 2, 1, 3,
                   2, 2, 3, 1,
                   1, 2, 2, 3,
                   3, 2, 1, 3 ]

      expected = [ [1, 3, 4, 2],
                   [4, 2, 1, 3],
                   [3, 4, 2, 1],
                   [2, 1, 3, 4] ]

      actual = solve_puzzle(clues)
      Test.assert_equals(actual, expected)
    end

=begin
    it "can solve 4x4 puzzle 2" do
      clues    = [0, 0, 1, 2,
                  0, 2, 0, 0,
                  0, 3, 0, 0,
                  0, 1, 0, 0]

      expected = [ [2, 1, 4, 3],
                   [3, 4, 1, 2],
                   [4, 2, 3, 1],
                   [1, 3, 2, 4] ]

      actual = solve_puzzle(clues)
      Test.assert_equals(actual, expected)
    end
=end
  end
end
