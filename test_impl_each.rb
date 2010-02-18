
require 'impl_each'


class TestImplEach
  include ImplEach
  include Enumerable

  def initialize(ary)
    @eachees = ary.dup
  end
end

