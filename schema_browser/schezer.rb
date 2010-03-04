#! /bin/env ruby

require 'mysql'
require 'yaml'
require 'optparse'


class CannotGetTableNameException < Exception
end

class TableSchema
  attr_reader :name, :primary_key, :unique_keys, :foreign_keys, :indexes
  attr_reader :engine, :default_charset, :comment

  def parse_raw_schema(lines)
    @name = nil
    lines.each do |line|
      next if /^\s*$/ =~ line
      parse_raw_line(line)


      break if @name


    end
  end

  private

    def parse_raw_line(line)
      @name = get_table_name_at_top(line) unless @name
    end

    def get_table_name_at_top(line)
      re = /^\s*CREATE TABLE `(\w+)` \(\s*$/
      m = Regexp.compile(re).match(line)
      raise CannotGetTableNameException unless m
      return m[1]
    end
end

class ColumnSchema
  attr_reader :name, :type, :not_null, :default, :auto_increment, :comment
end


class Schezer

  # config_filename: YAML 形式のデータベース接続情報を含んだファイルのファイル名。
  #                  形式は Rails の config/database.yml と同等
  # config_name:     接続情報の名称。Rails の環境名にあたる
  def initialize(argv)
    prepare_options(argv)

    config_filename = argv.shift
    configure(config_filename, @config_name)
    exit_with_msg("Cannot read necessary configuration\n#{self.to_s}") unless configuration_suffices?

    @conn = Mysql.new(@host, @username, @password, @database)
    get_query_result("SET NAMES #{@encoding}")

    @argv = argv
  end

  def execute
    command = @argv.shift
    return unless command

    case command
    when 'raw'
      table_name = @argv.shift
      puts get_raw_table_schema(table_name)
    when 'table'
      table_name = @argv.shift
      ts = parse_table_schema(table_name)

      puts "Table name = '#{ts.name}'"

    else
      exit_with_msg("Unknown command '#{command}'")
    end
  end

  def parse_table_schema(name)
    raw_schema = get_raw_table_schema(name)
    ts = TableSchema.new
    ts.parse_raw_schema(raw_schema.split("\n"))
    return ts
  end

  def get_table_names
    sql = "SHOW TABLES"
    result = get_query_result(sql)
    names = Array.new
    result.each do |name| names << name end
    return names
  end

  def get_raw_table_schema(name)
    sql = "SHOW CREATE TABLE #{name}"
    begin
      result = get_query_result(sql)
    rescue
      exit_with_msg("Failed to get schema for TABLE '#{name}'")
    end
    schema = result.fetch_hash['Create Table']
    return schema
  end

  def to_s
    return "host = #{@host}, username = #{@username}, " \
         + "password = #{non_empty_string?(@password) ? '*' * 8 : '(none)'}, database = #{@database}, " \
         + "encoding = #{@encoding}"
  end

  private

    def get_query_result(sql)
      return @conn.query(sql)
    end

    def configure(filename, name)
      exit_with_usage("Specify DB_config_filename") unless filename
      begin
        yaml = YAML.load_file(filename)
      rescue
        exit_with_msg("Cannot open file '#{filename}'")
      end

      hash_conf = yaml
      hash_conf = hash_conf[name] if name
      @host     = hash_conf['host']
      @username = hash_conf['username']
      @password = hash_conf['password']
      @database = hash_conf['database']
      @encoding = hash_conf['encoding']
    end

    def configuration_suffices?
      return non_empty_string?(@host, @username, @database)
    end

    def non_empty_string?(*args)
      args.each do |x|
        return false if ! x.kind_of?(String) || x.length == 0
      end
      return true
    end

    def exit_with_msg(msg=nil, exit_no=1)
      STDERR.puts msg if msg
      exit(exit_no)
    end

    def exit_with_usage(msg=nil, exit_no=1)
      msg_list = Array.new
      msg_list << msg if msg
      msg_list << "Usage: $0 DB_config_filename ...?"
      exit_with_msg(msg_list.join("\n"), exit_no)
    end

    def prepare_options(argv)
      @options = Hash.new { |h, k| h[k] = nil }
      opt_parser = OptionParser.new
      opt_parser.on("-e", "--environment=VAL" ) { |v| @config_name = v }
      opt_parser.parse!(argv)
    end
end


if __FILE__ == $0
  schezer = Schezer.new(ARGV)

  schezer.execute
end


#[EOF]

