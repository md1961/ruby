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
class << obj
  include MyModule
end

obj.my_method            # => "hello"
obj.singleton_methods    # => [:my_method]
