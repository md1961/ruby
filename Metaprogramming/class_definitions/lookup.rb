#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class C
  def a_method
    'C#a_method()'
  end
end

class D < C; end

obj = D.new
obj.a_method    # => "C#a_method()"

class << obj
  def a_singleton_method
    'obj#a_singleton_method()'
  end
end

class Object
  def eigenclass
    class << self; self; end
  end
end

"abc".eigenclass    # => #<Class:#<String:0x331df0>>

obj.eigenclass.superclass   # => D

class C
  class << self
    def a_class_method
      'C.a_class_method()'
    end
  end
end

C.eigenclass              # => #<Class:C>
D.eigenclass              # => #<Class:D>
D.eigenclass.superclass   # => #<Class:C>
C.eigenclass.superclass   # => #<Class:Object>

D.a_class_method          # => "C.a_class_method()"
