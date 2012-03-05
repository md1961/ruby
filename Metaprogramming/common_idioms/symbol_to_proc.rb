#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
names = ['bob', 'bill', 'heather']
names.map {|name| name.capitalize }   # => ["Bob", "Bill", "Heather"]

class Symbol
  def to_proc
    Proc.new {|x| x.send(self) }
  end
end

names = ['bob', 'bill', 'heather']
names.map(&:capitalize.to_proc)   # => ["Bob", "Bill", "Heather"]

names = ['bob', 'bill', 'heather']
names.map(&:capitalize)   # => ["Bob", "Bill", "Heather"]
