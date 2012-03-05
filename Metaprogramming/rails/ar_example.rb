#---
# Excerpted from "Metaprogramming Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/ppmetr for more book information.
#---
# Create a new database each time
File.delete 'dbfile' if File.exist? 'dbfile'

require 'activerecord'
ActiveRecord::Base.establish_connection :adapter => "sqlite3",
                                        :database => "dbfile" 

# Initialize the database schema
ActiveRecord::Base.connection.create_table :ducks do |t|
   t.string  :name
end

class Duck < ActiveRecord::Base
  validates_length_of :name, :maximum => 6
end

my_duck = Duck.new
my_duck.name = "Donald"
my_duck.valid?         # => true
my_duck.save!

some_duck = Duck.find(:first)
some_duck.id           # => 1
some_duck.name         # => "Donald"
some_duck.delete
