#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
begin
class Lawyer; end

nick = Lawyer.new
nick.talk_simple
rescue Exception => e
  e # => #<NoMethodError: undefined method `talk_simple' for #<Lawyer:0x38c9e4>>
end

begin
nick.send :method_missing, :my_method
rescue Exception => e
  e # => #<NoMethodError: undefined method `my_method' for #<Lawyer:0x38c9e4>>
end
