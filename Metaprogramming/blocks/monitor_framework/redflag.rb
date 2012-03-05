#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
def event(name, &block)
  @events[name] = block
end

def setup(&block)
  @setups << block
end

Dir.glob('*events.rb').each do |file|
  @setups = []
  @events = {}
  load file
  @events.each_pair do |name, event|
    env = Object.new
    @setups.each do |setup|
      env.instance_eval &setup
    end
    puts "ALERT: #{name}" if env.instance_eval &event
  end
end
