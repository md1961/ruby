#! /bin/env ruby

vim_option = nil
file_num = nil
if ARGV[0] == '-o' || ARGV[0] == '-p'
  vim_option = ARGV.shift
end
if ARGV[0] =~ /\A-([1-9])\z/
  file_num = Integer(Regexp.last_match(1))
elsif ARGV[0]
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
  }
filenames = [filenames[file_num - 1]] if file_num && file_num <= filenames.size

if vim_option || file_num
  system("vim #{vim_option} #{filenames.join(' ')}")
else
  puts filenames.join("\n")
end
