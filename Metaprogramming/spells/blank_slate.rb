#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class C
  def method_missing(name, *args)
    "a Ghost Method"
  end
end

obj = C.new
obj.to_s # => "#<C:0x357258>"
    
class C
  instance_methods.each do |m|
    undef_method m unless m.to_s =~ /^method_missing$|^respond_to\?$|^__/
  end
end

obj.to_s # => "a Ghost Method"
