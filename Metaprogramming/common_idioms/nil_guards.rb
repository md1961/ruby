#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
a ||= []

a || (a = [])

if a != nil
  a = a
else
  a = []
end

class C
  def initialize
    @a = []
  end
  
  def elements
    @a
  end
end

class C
  def elements
    @a ||= []
  end
end
