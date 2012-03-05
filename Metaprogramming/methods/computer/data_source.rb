#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
# In this example, we just fake the real service.

class DS
  def initialize # connect to data source...
  end
  
  def get_mouse_info(workstation_id) # ...
    "Dual Optical"
  end
  
  def get_mouse_price(workstation_id) # ...
    40
  end
  
  def get_keyboard_info(workstation_id) # ...
    "Standard UK"
  end
  
  def get_keyboard_price(workstation_id) # ...
    20
  end

  def get_cpu_info(workstation_id) # ...
      "2.16 Ghz"
    end

  def get_cpu_price(workstation_id) # ...
    220
  end

  def get_display_info(workstation_id) # ...
    "LED 1280x1024"
  end

  def get_display_price(workstation_id) # ...
  # ...and so on
    150
  end
end
