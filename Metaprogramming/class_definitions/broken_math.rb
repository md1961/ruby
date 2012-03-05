#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
require 'test/unit'

class Fixnum
  alias :old_plus :+
  
  def +(value)
    self.old_plus(value).old_plus(1)
  end
end

class BrokenMathTest < Test::Unit::TestCase
  def test_math_is_broken
    assert_equal 3, 1 + 1
    assert_equal 1, -1 + 1
    assert_equal 111, 100 + 10
  end
end
