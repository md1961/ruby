
class KnapsackSolver
  attr_reader :size

  def initialize(size)
    @size = size
  end
end

class Pack
  attr_reader :size, :price

  def initialize(size, price)
    @size  = size
    @price = price
  end
end
