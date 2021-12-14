#! /bin/env ruby

require 'time'
require 'readline'

MAX_LINES_OF_DIFF_OUTPUT = 40

def diff_output(file_info0, file_info1)
  return nil if file_info0.nil? || file_info1.nil?
  command = "diff #{file_info0.filename} #{file_info1.filename}"
  `#{command}`.yield_self { |output|
    lines = output.split("\n")
    if lines.size <= MAX_LINES_OF_DIFF_OUTPUT
      output
    else
      [
        lines.take(MAX_LINES_OF_DIFF_OUTPUT - 2).join("\n"),
        "... (#{ES_MAGENTA}rest is omitted.  Total lines = #{lines.size}#{ES_RESET})",
        "( command is: #{ES_MAGENTA}#{command}#{ES_RESET} )",
        ""
      ].join("\n")
    end
  }
end

ES_RED     = "\e[31m"
ES_MAGENTA = "\e[35m"
ES_CYAN    = "\e[36m"
ES_RESET = "\e[0m"

COMMAND_TO_LIST_FILES = "ls -gGrt --time-style=full-iso"

FileInfo = Struct.new(:filename, :size, :modified_at)

all_file_infos = `#{COMMAND_TO_LIST_FILES}`.split("\n").map { |line|
  line.split.values_at(-1, -4, -3, 2)
}.map { |filename, date, time, size|
  next unless [filename, date, time, size].all?
  FileInfo.new(filename, Integer(size), Time.parse("#{date} #{time}"))
}.compact

PROMPT = "=== Remove #{ES_RED}all except #{ES_CYAN}the last file#{ES_RESET}? (y/N/q)> "

all_file_infos.chunk_while { |file_info0, file_info1|
  file_info0.size == file_info1.size
}.each do |file_infos|
  next if file_infos.size <= 1
  raise "Files with different sizes included" unless file_infos.map(&:size).uniq.size == 1

  system('clear')

  size = file_infos.first.size
  index_last = file_infos.size - 1
  last_file_info = nil
  file_infos.each.with_index do |file_info, index|
    print diff_output(last_file_info, file_info)

    print index == index_last ? ES_CYAN : ES_RED
    print "#{file_info.size}  #{file_info.modified_at}  #{file_info.filename}"
    print ES_RESET
    puts

    last_file_info = file_info
  end

  response = nil
  until %w[y n q].include?(response)
    response = Readline.readline(PROMPT)
    response = 'n' if response.empty?
  end
  break if response == 'q'

  puts
  next if response == 'n'

  filenames_to_remove = file_infos[0 .. -2].map(&:filename)
  begin
    File.delete(*filenames_to_remove)
    puts "Removed: #{filenames_to_remove.join(', ')}"
    puts
  rescue
    STDERR.puts "#{ES_RED}FAILED to remove file(s)#{ES_RESET}"
    STDERR.puts $!.inspect
    exit
  end
end
