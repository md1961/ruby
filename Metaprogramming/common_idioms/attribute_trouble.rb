#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class MyClass
  attr_accessor :my_attr
  
  def initialize_attributes
    my_attr = 10
  end
end

obj = MyClass.new
obj.initialize_attributes
obj.my_attr                 # => nil

class MyClass
  def initialize_attributes
    self.my_attr = 10
  end
end

obj.initialize_attributes
obj.my_attr                 # => 10
