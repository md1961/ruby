#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class MyClass
  def initialize
    @v = 1
  end
end

obj = MyClass.new
obj.instance_eval do
  self        # => #<MyClass:0x3340dc @v=1>
  @v          # => 1
end

v = 2
obj.instance_eval { @v = v }
obj.instance_eval { @v }      # => 2
