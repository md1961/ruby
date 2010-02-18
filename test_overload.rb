
class TestOverload
  def initialize
    @a = 0
  end

  def a=(x, yes=true)
    @a = x if yes
  end

  def to_s
    "@a = #{@a}"
  end
end

