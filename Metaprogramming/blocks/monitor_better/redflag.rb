#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
def define_redflag!
  setups = []
  events = {}

  self.class.class_eval do
    define_method :event do |name, &block|
      events[name] = block
    end

    define_method :setup do |&block|
      setups << block
    end
    
    define_method :events do
      events
    end

    define_method :setups do
      setups
    end
  end
end

define_redflag!

Dir.glob('*events.rb').each do |file|
  load file
  events.each_pair do |name, event|
    env = Object.new
    setups.each do |setup|
      env.instance_eval &setup
    end
    puts "ALERT: #{name}" if env.instance_eval &event
  end
end
