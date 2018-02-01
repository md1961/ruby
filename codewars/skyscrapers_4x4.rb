def solve_puzzle(clues)
  Skyscraper.new(4).solve(clues)
end

class Skyscraper
  NORTH = :north
  SOUTH = :south
  EAST  = :east
  WEST  = :west
  ALL_SIDES = [NORTH, EAST, SOUTH, WEST]

  def initialize(n_grids)
    @n_grids = n_grids
    @num_seen_lookup = create_num_seen_lookup
  end

  def solve(clues)
    @heights = Array.new(@n_grids) {
      Array.new(@n_grids) { all_heights.join }
    }
    ALL_SIDES.cycle do |side|
      use_clues_on(side, clues_on(side, clues))
      break if solved?
    end
    @heights.map { |row| row.map(&:to_i) }
  end

  private

    def all_heights
      (1 .. @n_grids).to_a.map(&:to_s)
    end

    def solved?
      @heights.flatten.all? { |h| h.size == 1 }
    end

    def num_seen(row)
      num_seen_on_front = 1
      (1 ... @n_grids).reduce(num_seen_on_front) { |num, index|
        num + (row[index] > row[0, index].max ? 1 : 0)
      }
    end

    def create_num_seen_lookup
      all_heights.permutation.group_by { |row| num_seen(row) }
    end

    def clues_on(side, clues)
      case side
      when NORTH
        clues[@n_grids * 0, @n_grids]        
      when EAST 
        clues[@n_grids * 1, @n_grids]        
      when SOUTH
        clues[@n_grids * 2, @n_grids].reverse
      when WEST 
        clues[@n_grids * 3, @n_grids].reverse
      end
    end

    def use_clues_on(side, clues_for_side)
      rotate_target_side_to_left(side)
      @heights.zip(clues_for_side) do |row, clue|
        remove_possibilities_for(row, clue)
      end
      remove_unnecessary_posibilities
      confirm_sole_possibility
      restore_rotation(side)
    end

    def remove_possibilities_for(row, clue)
      return if clue.zero?
      possibles = @num_seen_lookup[clue]
      if possibles.size == 1
        row.size.times { |i| row[i] = possibles.first[i] }
      else
        possibles = possibles.find_all { |possible|
          possible.zip(row).all? { |p, cell| cell.index(p) }
        }
        combined_possibles = possibles.reduce([''] * @n_grids) { |result, possible|
          result.zip(possible).map { |r, p| r + p }
        }.map { |p| p.chars.uniq.sort.join }
        row.size.times { |i| row[i] = combined_possibles[i] }
      end
    end

    def remove_unnecessary_posibilities
      @heights.each do |row|
        row.size.times do |index|
          remove_other_possibilities_than(index, row)
        end
      end
    end

    def confirm_sole_possibility
      @heights.each do |row|
        all_heights.each do |h|
          if row.one? { |cell| cell.index(h) }
            index = row.index { |cell| cell.index(h) }
            row[index] = h
            remove_other_possibilities_than(index, row)
          end
        end
      end
    end

    def remove_other_possibilities_than(index, row)
      return if row[index].size != 1
      row.size.times do |i|
        next if i == index
        remove_possibility_of(row[index], row, i)
      end
    end

    def remove_possibility_of(height, row, index)
      cell_after = row[index].delete!(height)
      raise RuntimeError, "row = #{row.inspect}, index = #{index}, height = #{height}" \
        if cell_after && row[index].size == 0
      remove_other_possibilities_than(index, row) if cell_after
    end

    def rotate_target_side_to_left(side)
      case side
      when NORTH
        @heights = @heights.transpose
      when EAST
        @heights = @heights.map(&:reverse)
      when SOUTH
        @heights = @heights.transpose.map(&:reverse)
      end
    end

    def restore_rotation(side)
      if side == SOUTH
        @heights = @heights.map(&:reverse).transpose
      else
        rotate_target_side_to_left(side)
      end
    end
end


  def print_heights(heights, side = nil, clues_for_side = [])
    puts side.to_s.upcase
    4.times do |i|
      puts "#{clues_for_side[i]} : #{heights[i].map { |h| h.center(4) }.join(' ')}"
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
  end
end
