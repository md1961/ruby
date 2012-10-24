#! /usr/local/bin/ruby

if ARGV.size != 2
  $stderr.puts "Usage: #{File.basename($0)} string_at_true_newline filename"
  exit
end

string_at_true_newline = ARGV[0]
filename = ARGV[1]

=begin
puts "Substitute newlines ending with other than '#{string_at_true_newline}' in file '#{filename}'"
begin
  print "OK to proceed(y/n)? "
  c = $stdin.getc
  puts
  if c == 'n'
    $stderr.puts "Quit according to user's request"
    exit
  end
end until c == 'y' || c == 'Y'
=end

unless File.exists?(filename)
  $stderr.puts "Cannot find file '#{filename}'"
  exit
end

NEWLINE_SUBSTITUTION = '<br />'

File.open(filename, 'r') do |f|
  buffer = ''
  while line = f.gets
    line.chomp!
    length = string_at_true_newline.length
    string_at_end = line[-length, length]
    buffer += line
    if string_at_end != string_at_true_newline
      buffer += NEWLINE_SUBSTITUTION
    else
      $stdout.puts buffer
      buffer = ''
    end
  end
  $stdout.puts buffer unless buffer.empty?
end

