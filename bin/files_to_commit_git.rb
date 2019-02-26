#! /bin/env ruby

FILE_EXTENSIONS_TO_EXCLUDE = %w[.sqlite3]

DEFAULT_VIM_OPTION = '-o' 

vim_option = nil
if ARGV[0] == '-o' || ARGV[0] == '-p'
  vim_option = ARGV.shift
end

file_nums = []
while ARGV[0] =~ /\A-([1-9])\z/ do
  file_nums << Integer(Regexp.last_match(1))
  ARGV.shift
end
file_nums.uniq!
vim_option = DEFAULT_VIM_OPTION if file_nums.size >= 2 && !vim_option

if ARGV[0]
  STDERR.puts "Unknown flag #{ARGV[0]}"
  STDERR.puts "Usage: #{File.basename($0)} [-[op] [-#]] (pass -[op] to vim)"
  exit
end

INDENTS = [' ' * 8, "\t"]

line_with_file = `git status`.split("\n").select { |line| line =~ /\A#{INDENTS.join('|')}/ }
filenames = \
  line_with_file.map { |line|
    line.sub(/\A\s*(?:modified:|new file:)?\s*/, '')
  }.flat_map { |filename|
    filename.end_with?('/') ? Dir.glob("#{filename}*") : filename
  }.reject { |filename|
    FILE_EXTENSIONS_TO_EXCLUDE.any? { |ext| filename.end_with?(ext) }
  }

file_nums.each do |file_num|
  if file_num > filenames.size
    STDERR.puts "File number (#{file_num}) out of range"
    exit
  end
end

file_nums.map! { |n| n - 1 }
filenames = filenames.values_at(*file_nums) if file_nums.size > 0

if vim_option || file_nums.size > 0
  system("vim #{vim_option} #{filenames.join(' ')}")
else
  filenames.each.with_index(1) do |filename, index|
    puts "%2d: %s\n" % [index, filename]
  end
end
