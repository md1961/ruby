#! /usr/bin/env ruby

# Ruby の正規表現を用いた grep を実現するスクリプト

require 'optparse'


#= Ruby の正規表現を用いた grep を実現するクラス
class RubyGrep
  MAX_LINES_FOR_MULTI_LINES = 20
  JOINT_FOR_MULTI_LINES = ' '
  DEFAULT_FILENAMES_FOR_OPTION_R = '*rb'

  # コンストラクタ
  # <em>argv</em> :: コマンドライン引数
  def initialize(argv)
    compile_option = 0
    prepare_options(argv)
    compile_option |= Regexp::IGNORECASE if @options[:i]

    pattern = argv.shift
    exit_with_usage unless pattern
    @re = Regexp.compile(pattern, compile_option)

    @filenames = argv
    @filenames = DEFAULT_FILENAMES_FOR_OPTION_R if @options[:r] && argv.empty?
    check_file_existence((dir = @options[:r]) ? [dir] : @filenames)
  end

  # コンストラクト時の引数に基づき grep を実行し、結果を出力する
  def grep
    do_grep
  end

  private

    def do_grep
      multi_lines = Array.new

      if dir = @options[:r]
        dir.chomp!('/')
        glob_filenames = Array.new
        @filenames.each do |filename|
          glob_filenames += Dir.glob("#{dir}/**/#{filename}")
        end
        @filenames = glob_filenames
      end

      @filenames.each do |filename|
        count = 0
        lineno = 0
        File.open(filename, 'r').each do |line|
          matched, is_over_multi_lines = match(line, multi_lines)
          lineno += 1

          if matched
            count += 1
            multi_lines = Array.new
            finishes_file = print_matched(matched, filename, lineno, is_over_multi_lines)
            break if finishes_file
          end
        end

        if @options[:c] && count > 0
          puts "#{filename}: #{count}"
        end
      end
    end

    def match(line, multi_lines)
      line.chomp!
      matched = nil
      is_over_multi_lines = false
      if @re =~ line
        matched = line
      elsif @options[:m]
        multi_lines << line
        max_lines = MAX_LINES_FOR_MULTI_LINES
        if max_lines > 0 && multi_lines.size > max_lines
          multi_lines = multi_lines[-max_lines .. -1]
        end
        matched = multi_line_match(multi_lines)
        is_over_multi_lines = true
      end

      return matched, is_over_multi_lines
    end

    # Last element of multi_lines (Array of String) is newly added line.
    # Match will not achieved if trying without the new line.
    # Neither if trying with only the new line.
    def multi_line_match(multi_lines)
      (multi_lines.size - 2).downto(0) do |index_start|
        concat_line = multi_lines[index_start .. -1].join(JOINT_FOR_MULTI_LINES)
        return multi_lines[index_start .. -1].join("\n") if @re =~ concat_line
      end

      return nil
    end

    def print_matched(matched, filename, lineno, is_over_multi_lines)
      if @options[:l]
        puts filename
        return true
      elsif ! @options[:c]
        line_number = @options[:n] ? ":#{lineno}" : ""
        print "#{filename}#{line_number}: " if @filenames.size > 1
        prefix, postfix = is_over_multi_lines ? ["[multi]>>\n", "\n<<[multi]"] : ["", ""]
        puts "#{prefix}#{matched}#{postfix}"
        return false
      end
    end

    def prepare_options(argv)
      @options = Hash.new { |h, k| h[k] = nil }
      opt_parser = OptionParser.new
      opt_parser.on("-c", "--count"                ) { |v| @options[:c] = true }
      opt_parser.on("-i", "--ignore-case"          ) { |v| @options[:i] = true }
      opt_parser.on("-l", "--files-with-matches"   ) { |v| @options[:l] = true }
      opt_parser.on("-m", "--multi-lines"          ) { |v| @options[:m] = true }
      opt_parser.on("-n", "--line-number"          ) { |v| @options[:n] = true }
      opt_parser.on("-r", "--recursive DIR"        ) { |v| @options[:r] = v }
      opt_parser.parse!(argv)
    end

    def check_file_existence(filenames)
      filenames.each do |filename|
        unless File.exist?(filename)
          STDERR.puts "Cannot find file '#{filename}'"
          exit
        end
      end
    end

    def exit_with_usage
      command = File.basename($0)
      puts "Usage: #{command} [options] pattern filename ..."
      system("#{$0} --help | grep -v '^Usage'")
      exit(1)
    end
end


if __FILE__ == $0
  ruby_grep = RubyGrep.new(ARGV)
  ruby_grep.grep
end


# The followings are currently not in use.

OPTIONS = [
  ["-c", "--count"],
  ["-l", "--files-with-matches"],
]

class ProgramConfig
  attr_reader :parser

  def initialize
    @hash_config = Hash.new { |h, k| h[k] = false }
    @parser = OptionParser.new
  end

  def on(*opts, &block)
    @parser.on(*opts, &block)
  end

  def parse!(argv)
    @parser.parse!(argv)
  end
end
