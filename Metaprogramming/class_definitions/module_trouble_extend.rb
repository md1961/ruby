#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
module MyModule
  def my_method; 'hello'; end
end

obj = Object.new
obj.extend MyModule
obj.my_method       # => "hello"

class MyClass
  extend MyModule
end
MyClass.my_method   # => "hello"
