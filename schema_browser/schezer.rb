#! /usr/bin/env ruby

require 'mysql'
require 'yaml'
require 'optparse'


class CannotGetTableNameException < Exception
end

class UnsupportedColumnDefinitionException < Exception
end

class DuplicatePrimaryKeyException < Exception
end

class TableSchema
  attr_reader :name, :columns, :primary_key, :unique_keys, :foreign_keys, :keys
  attr_reader :engine, :default_charset, :comment

  def initialize
    @name    = nil
    @columns = Array.new
    @primary_key  = Array.new
    @unique_keys  = Array.new
    @foreign_keys = Array.new
    @keys         = Array.new
  end

  def parse_raw_schema(lines)
    lines.each do |line|
      next if /^\s*$/ =~ line
      parse_raw_line(line)
    end
  end

  def to_s
    schemas = Array.new
    schemas << "TABLE `#{@name}`"
    @columns.each do |column|
      schemas << column.to_s
    end
    schemas << "primary key = `#{@primary_key.join('`,`')}`" if primary_key
    @unique_keys.each do |unique|
      schemas << unique.to_s
    end
    @foreign_keys.each do |foreign|
      schemas << foreign.to_s
    end
    return schemas.join("\n")
  end

  private

    def parse_raw_line(line)
      if @name.nil?
        @name = get_table_name_at_top(line)
        return
      end
      column_schema = ColumnSchema.parse(line)
      if column_schema
        @columns << column_schema
        return
      end
      if get_key(line)
        return
      end
    end

    RE_PK = /^\s*PRIMARY KEY\s+\(`(\w+)`\),?\s*$/

    def get_key(line)
      if m = Regexp.compile(RE_PK).match(line)
        raise DuplicatePrimaryKeyException.new("#{@primary_key} and #{m[1]}") if @primary_key.size > 0
        @primary_key = m[1].split(/`,\s*`/)
        return true
      end
      if unique = UniqueKey.parse(line)
        @unique_keys << unique
        return true
      end
      if foreign = ForeignKey.parse(line)
        @foreign_keys << foreign
        return true
      end
      return false
    end

    RE_TABLE_NAME = /^\s*CREATE TABLE `(\w+)` \(\s*$/

    def get_table_name_at_top(line)
      m = Regexp.compile(RE_TABLE_NAME).match(line)
      raise CannotGetTableNameException.new("in \"#{line}\"") unless m
      return m[1]
    end
end

class ColumnSchema
  attr_reader :name, :type, :not_null, :default, :auto_increment, :comment

  RE = /^\s*`(\w+)`\s+(.*?)\s*(?:COMMENT\s+'(.*)')?\s*,?\s*$/

  def self.parse(line)
    m = Regexp.compile(RE).match(line)
    return nil unless m
    name       = m[1]
    definition = m[2]
    comment    = m[3]
    return ColumnSchema.new(name, definition, comment)
  end

  def initialize(name, definition, comment)
    @name    = name
    @comment = comment
    parse_definition(definition)
  end

  def to_s
    ar_str = Array.new
    ar_str << "`#{@name}`:#{@type}"
    ar_str << "not_null" if @not_null
    ar_str << "default=#{@default}" if @default
    ar_str << "auto_increment" if @auto_increment
    ar_str << "[#{@comment}]"
    return ar_str.join(' ')
  end

  private

    def parse_definition(definition)
      terms = definition.split
      @type = get_type(terms)
      begin
        @not_null, @default, @auto_increment = get_null_default_and_auto_increment(terms)
      rescue UnsupportedColumnDefinitionException => evar
        raise UnsupportedColumnDefinitionException.new(evar.message + " in \"#{definition}\"")
      end
    end

    TERMS_TO_SUPPLEMENT_TYPE = %w(unsigned zerofill binary ascii unicode)

    def get_type(terms)
      type_elements = Array.new
      begin
        type_elements << terms.shift
      end while terms.size > 0 && TERMS_TO_SUPPLEMENT_TYPE.include?(terms[0])
      return type_elements.join(' ')
    end

    #  [NOT NULL | NULL] [DEFAULT default_value] [AUTO_INCREMENT]
    def get_null_default_and_auto_increment(terms)
      not_null = false
      default = nil
      auto_increment = false
      while terms.size > 0
        if terms[0] == 'NOT' && terms[1] == 'NULL'
          not_null = true
          terms.shift; terms.shift
        elsif terms[0] == 'default'
          default = terms[1]
          terms.shift; terms.shift
        elsif terms[0] == 'auto_increment'
          auto_increment = true
          terms.shift
        else
          str_terms = terms.join(' ')
          raise UnsupportedColumnDefinitionException.new("Cannot handle \"#{str_terms}\"")
        end
      end
      return not_null, default, auto_increment
    end
end

class UniqueKey
  attr_reader :name, :column_names

  RE = /^\s*UNIQUE KEY\s+`(\w+)`\s+\(`([\w`, ]+)`\),?\s*$/

  def self.parse(line)
    m = Regexp.compile(RE).match(line)
    return nil unless m
    name = m[1]
    column_names = m[2].split(/`,\s*`/)
    return UniqueKey.new(name, column_names)
  end

  def initialize(name, column_names)
    @name = name
    @column_names = column_names
  end

  def to_s
    return "unique key `#{name}` (`#{column_names.join('`,`')}`)"
  end
end

class ForeignKey
  attr_reader :name, :column_name, :ref_table_name, :ref_column_name, :on_update, :on_delete

  DEFAULT_ON_UPDATE = "RESTRICT"
  DEFAULT_ON_DELETE = "RESTRICT"

  #         CONSTRAINT   `$    `   FOREIGN KEY    (`$    ` )   REFERENCES   `$    `    (`$    ` ) ON UPDATE CASCADE
  RE = /^\s*CONSTRAINT\s+`(\w+)`\s+FOREIGN KEY\s+\(`(\w+)`\)\s+REFERENCES\s+`(\w+)`\s+\(`(\w+)`\)(?:\s+ON DELETE (\w+))?(?:\s+ON UPDATE (\w+))?\s*$,?\s*/

  def self.parse(line)
    m = Regexp.compile(RE).match(line)
    return nil unless m
    name = m[1]
    column_name = m[2]
    ref_table_name = m[3]
    ref_column_name = m[4]
    on_delete = m[5]
    on_update = m[6]
    on_delete = DEFAULT_ON_DELETE unless on_delete
    on_update = DEFAULT_ON_UPDATE unless on_update
    return ForeignKey.new(name, column_name, ref_table_name, ref_column_name, on_delete, on_update)
  end

  def initialize(name, column_name, ref_table_name, ref_column_name, on_delete, on_update)
    @name = name
    @column_name = column_name
    @ref_table_name = ref_table_name
    @ref_column_name = ref_column_name
    @on_delete = on_delete
    @on_update = on_update
  end

  def to_s
    return "foreign key `#{@name}` (`#{@columns}`) refs `#{@ref_table_name}` (`#{@ref_column_name}`)\n" \
         + "    on update #{@on_update} on delete #{@on_delete}"
  end
end


class Schezer

  # config_filename: YAML 形式のデータベース接続情報を含んだファイルのファイル名。
  #                  形式は Rails の config/database.yml と同等
  # config_name:     接続情報の名称。Rails の環境名にあたる
  def initialize(argv)
    prepare_options(argv)

    configure(@config_filename, @config_name)
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
      puts ts
    when 'all'
      puts get_table_names.join(' ')
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
    rescue CannotGetTableNameException => evar
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
      msg_list << "Usage: #{$0} DB_config_filename ...?"
      exit_with_msg(msg_list.join("\n"), exit_no)
    end

    def prepare_options(argv)
      @options = Hash.new { |h, k| h[k] = nil }
      opt_parser = OptionParser.new
      opt_parser.on("-e", "--environment=VALUE" ) { |v| @config_name     = v }
      opt_parser.on("-f", "--config_file=VALUE" ) { |v| @config_filename = v }
      opt_parser.parse!(argv)
    end
end


if __FILE__ == $0
  schezer = Schezer.new(ARGV)

  schezer.execute
end


#[EOF]

