
class KnapsackSolver
  attr_reader :size

  PACK_ATTRS = [
    [ 4, 6 ],
    [ 3, 4 ],
    [ 1, 1 ],
  ]

  def initialize(size)
    @size = size
    @possible_packs = make_possible_packs
  end

    def make_possible_packs
      return PACK_ATTRS.map { |size, price| Pack.new(size, price) }
    end
    private :make_possible_packs

  def solve
    @array_move = prepare_array_move
  end

  private

    def prepare_array_move
      array_move = Array.new
      @size.times do
        array_move < Move.new
      end
      return array_move
    end

    def do_solve
      @possible_packs.each do |pack|
        @array_move.each do |move|
          move.fill(pack)
        end
      end
    end
end

class Pack
  attr_reader :size, :price

  def initialize(size, price)
    @size  = size
    @price = price
  end
end

class Move
  attr_accessor :size, :amount

  def initialize
    @size   = 0
    @amount = 0
  end

  def fill(pack)

  end
end

