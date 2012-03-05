#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
class MyClass
  def my_method
    @v = 1
  end
end

obj = MyClass.new
obj.class           # => MyClass

obj.my_method
obj.instance_variables  # => [:@v]

obj.methods.grep(/my/)  # => [:my_method]

String.instance_methods == "abc".methods    # => true
String.methods == "abc".methods             # => false
