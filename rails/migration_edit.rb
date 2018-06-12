#! /bin/env ruby

require 'readline'
require_relative 'rails_util'
require 'active_support/inflector'

unless RailsUtil.rails_dir?
  STDERR.puts "Quit execution as you're not in a Rails root directory."
  exit
end

filenames = Dir.glob('db/migrate/*.rb').sort

filenames.each.with_index(1) do |filename, index|
  migration_name = filename.sub(%r!db/migrate/\d+_!, '').gsub('_', ' ').gsub(/\.rb\z/, '')
  migration_name.sub!(/\b(create |to )(\w.*)\z/) {
    model_name_parts = $2.split
    model_name_parts[-1] = model_name_parts.last.singularize
    $1 + model_name_parts.map(&:capitalize).join
  }
  puts format('%3d: %s', index, migration_name)
end

indexes = []
puts '--------------------------------'
loop do
  str_numbers = Readline.readline("Enter No.'s to edit: ")
  exit unless str_numbers =~ /\A[\d ]+\z/
  indexes = str_numbers.split.map { |n| Integer(n) - 1 }
  break if indexes.all? { |index| index < filenames.size }
end

filenames_to_edit = filenames.values_at(*indexes)
system("vim -o #{filenames_to_edit.join(' ')}")
