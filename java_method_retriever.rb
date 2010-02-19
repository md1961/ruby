#! /usr/bin/env ruby


class JavaMethodRetriever

  RE_STARTING_KEYWORDS_FOR_TARGET = /^\s*(package|public)\s/
  CHARS_AS_END_OF_LOGICAL_LINE = ";{"

  def initialize(java_filename)
    @filename = java_filename
  end

  def analyze
    open(@filename, "r") do |file|
      logical_line = ""
      file.each do |line|
        if RE_STARTING_KEYWORDS_FOR_TARGET =~ line
          ??
        line_to_end = end_of_logical_line(line)
        unless line_to_end
          logical_line += line
          next
        end
        logical_line += line_to_end
        filter_and_print(logical_line)
      end
    end
  end

  private

    def end_of_logical_line(line)
      aline = line.gsub(/"[^"]*"/, '""')
    end
end


if __FILE__ == $0
  java_filename = ARGV[0]

  jmr = JavaMethodRetriever.new(java_filename)
  jmr.analyze
end

#[EOF]
