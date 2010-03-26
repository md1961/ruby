#! /usr/bin/env ruby

# Ruby の正規表現を用いた rename を実現するスクリプト

class RegexpFileRenamer

  def initialize(pattern, substitute, filenames, simulates)
    @pattern = RegexpFileRenamer.compile pattern
    @substitute = substitute
    @filenames = filenames
    @simulates = simulates 
  end

  def exec
    @filenames.each { |filename|
      if @pattern =~ filename
        new_filename = filename.sub(@pattern, @substitute)
        if @simulates
          print "#{new_filename} <= #{filename}\n"
          next
        end
        File.rename(filename, new_filename)
      end
    }
  end

  def self.compile(pattern)
    begin
      Regexp.compile(pattern)
    rescue RegexpError
      STDERR.print "'#{pattern}' is an invalid Regexp\n"
      exit(1)
    end
  end
end


if __FILE__ == $0
  SCRIPT_NAME = $0.split('/')[-1]
  USAGE = "Usage: #{SCRIPT_NAME} [-s|--simulate] pattern substitute filename [...]"

  if ARGV.length < 3
    STDERR.print "#{USAGE}\n"
    STDERR.flush
    exit(1)
  end

  # Get a regular expression and a substituting string
  simulates = false
  pattern = ARGV.shift
  if pattern == '-s' || pattern == '--simulate'
    simulates = true
    pattern = ARGV.shift
  end
  substitute = ARGV.shift

  rfr = RegexpFileRenamer.new(pattern, substitute, ARGV, simulates)
  rfr.exec
end

