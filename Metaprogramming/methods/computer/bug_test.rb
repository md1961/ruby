#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
# A unit test for the bug in the proxy-based Computer

require 'test/unit'

class ComputerTest < Test::Unit::TestCase
  def test_works_correctly_with_display
    assert_equal '* Display: LED 1280x1024 ($150)', @computer.display
  end

  # ...
end
