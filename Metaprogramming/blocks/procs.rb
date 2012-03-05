#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
inc = Proc.new {|x| x + 1 }
# more code...
inc.call(2) # => 3

dec = lambda {|x| x - 1 }
dec.class # => Proc
dec.call(2) # => 1

p = proc {|x| x + 1 }
p.class # => Proc
