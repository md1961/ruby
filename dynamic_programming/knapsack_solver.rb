#! /usr/bin/env ruby


class KnapsackSolver
  attr_reader :size

  def initialize(size)
    @size = size
  end

  def self.make_possible_packs(pack_attrs)
    return pack_attrs.map { |size, price| Pack.new(size, price) }
  end

  def solve(pack_attrs)
    @possible_packs = KnapsackSolver.make_possible_packs(pack_attrs)
    @array_move = prepare_array_move
    do_solve

    puts self
    puts

  end

  def to_s
    outs = Array.new
    indexes = (0 .. @size).to_a
    [
      [''      , indexes],
      ['size'  , indexes.map { |i| @array_move[i].size   }],
      ['amount', indexes.map { |i| @array_move[i].amount }],
    ].each do |label, values|
      s  = sprintf("%6s : ", label)
      s += values.map { |value| sprintf("%3d", value) }.join('')
      outs << s
    end
    return outs.join("\n")
  end

  private

    def prepare_array_move
      array_move = Array.new
      (@size + 1).times do
        array_move << Move.new
      end
      return array_move
    end

    def do_solve
      @possible_packs.each do |pack|
        pack.size.upto(@size) do |index|
          fill(index, pack)
        end
      end
    end

    def fill(index, pack)
      move_src  = @array_move[index - pack.size]
      move_dest = @array_move[index]
      expected_amount = move_src.amount + pack.price
      if expected_amount > move_dest.amount
        move_dest.size   = pack.size
        move_dest.amount = expected_amount
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
end


P4 = [ 4, 6 ]
P3 = [ 3, 4 ]
P1 = [ 1, 1 ]

if __FILE__ == $0
  ks = KnapsackSolver.new(10)
  ks.solve([P4, P3, P1])
  ks.solve([P3, P4, P1])
  ks.solve([P1, P3, P4])
  ks.solve([P1, P4, P3])
end


#[EOF]

