#! /bin/env ruby

opens_with_vim = false
if ARGV[0] == '-o' || ARGV[0] == '-p'
  opens_with_vim = true
elsif ARGV[0]
  STDERR.puts "Usage: #{File.basename($0)} [-[op]] (pass options to vim)"
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

if opens_with_vim
  system("vim #{ARGV[0]} #{filenames.join(' ')}")
else
  puts filenames.join("\n")
end
