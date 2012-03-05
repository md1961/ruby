#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
def math(a, b)
  yield(a, b)
end

def teach_math(a, b, &operation)
  puts "Let's do the math:"
  puts math(a, b, &operation)
end

teach_math(2, 3) {|x, y| x * y}

def my_method(&the_proc)
  the_proc
end

p = my_method {|name| "Hello, #{name}!" }
puts p.class
puts p.call("Bill")
