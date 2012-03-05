#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class MyClass
  attr_accessor :a
end

obj = MyClass.new
obj.a = 2
obj.a         # => 2

class MyClass; end

class Class
  attr_accessor :b
end

MyClass.b = 42
MyClass.b      # => 42

class MyClass
  class << self
    attr_accessor :c
  end
end

MyClass.c = 'It works!'
MyClass.c               # => "It works!"

def MyClass.c=(value)
  @c = value
end

def MyClass.c
  @c
end
