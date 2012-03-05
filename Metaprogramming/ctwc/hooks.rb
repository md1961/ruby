#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class String
  def self.inherited(subclass)
    puts "#{self} was inherited by #{subclass}"
  end
end

class MyString < String; end

module M
  def self.included(othermod)
    puts "M was mixed into #{othermod}"
  end
end

class C
  include M
end

module M
  def self.method_added(method)
    puts "New method: M##{method}"
  end
  
  def my_method; end
end
