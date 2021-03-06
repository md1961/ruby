#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
a = 1
defined? a # => "local-variable"

module MyModule
  b = 1
  defined? a # => nil
  defined? b # => "local-variable"
end

defined? a  # => "local-variable"
defined? b  # => nil
