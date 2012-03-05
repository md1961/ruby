#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
def double(callable_object)
  callable_object.call * 2
end  

l = lambda { return 10 }
double(l) # => 20

def another_double
  p = Proc.new { return 10 }
  result = p.call
  return result * 2  # unreachable code!
end

another_double # => 10

p = Proc.new { return 10 }
# This fails with a LocalJumpError:
# double(p)    

p = Proc.new { 10 }
double(p)   # => 20

p = Proc.new {|a, b| [a, b]}
p.arity # => 2

p = Proc.new {|a, b| [a, b]}
p.call(1, 2, 3)   # => [1, 2]
p.call(1)         # => [1, nil]
