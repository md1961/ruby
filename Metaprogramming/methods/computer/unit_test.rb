#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
# A basic unit test for the Computer class

require 'data_source'
require 'test/unit'

class ComputerTest < Test::Unit::TestCase
  def setup
    @computer = Computer.new(42, DS.new)
  end
  
  def test_returns_a_printable_description
    assert_equal "Mouse: Dual Optical ($40)", @computer.mouse
  end
  
  def test_marks_expensive_items_with_an_asterisk
    assert_equal "* Cpu: 2.16 Ghz ($220)", @computer.cpu
  end
end
