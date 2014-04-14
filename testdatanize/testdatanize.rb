#! /usr/local/bin/ruby

require 'date'

DELIMITER = "\t"
COMMAND_TO_PICK_CHAR_FROM_FILE = '{pick}'
COMMAND_TO_WRITE_RANDOM_DATE   = '{date}'

field_number = Integer(ARGV[0])
pattern_replace = ARGV[1]
replace_to      = ARGV[2]

file_to_pick_char_from = ARGV[3] && open(ARGV[3], 'r')
chars_to_pick_from = file_to_pick_char_from.gets.chomp.split(//) if file_to_pick_char_from

while STDIN.gets
  fields = $_.chomp.split(DELIMITER)

  if replace_to == COMMAND_TO_WRITE_RANDOM_DATE
    current_year = Date.today.year
    date_from = Date.parse("#{current_year - 40}-01-01")
    date_to   = Date.parse("#{current_year -  2}-12-31")
    days = date_to - date_from - 1
    fields[field_number] = (date_from + rand(days)).to_s
  else
    chars = fields[field_number].split(//).map do |char|
      if char !~ /#{pattern_replace}/
        char
      elsif replace_to == COMMAND_TO_PICK_CHAR_FROM_FILE
        chars_to_pick_from.sample
      else
        replace_to
      end
    end
    fields[field_number] = chars.join
  end

  puts fields.join(DELIMITER)
end

