#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
@var = "The top-level @var"

def my_method
  @var
end

my_method # => "The top-level @var"

class MyClass
  def my_method
    @var = "This is not the top-level @var!"
  end
end
