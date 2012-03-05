#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
module M
  class C
    X = 'a constant'
  end

  C::X # => "a constant"
end

M::C::X # => "a constant"

module M
  Y = 'another constant'
  
  class C
    ::M::Y    # => "another constant"
  end
end

M.constants              # => [:C, :Y]
Module.constants[0..1]   # => [:Object, :Module]

module M
  class C
    module M2
      Module.nesting    # => [M::C::M2, M::C, M]
    end
  end
end
