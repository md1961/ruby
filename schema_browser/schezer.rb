#! /usr/bin/env ruby

require 'mysql'
require 'yaml'
require 'optparse'
require 'rexml/document'


class CannotGetTableNameException < Exception
end

class CannotGetTableOptionsException < Exception
end

class UnsupportedColumnDefinitionException < Exception
end

class DuplicatePrimaryKeyException < Exception
end

class CannotCompareDueToSchemaDiscrepancyException < Exception
end

class NotComparedYetException < Exception
end

class TableSchemaDifference
  attr_reader :column_names_only1, :column_names_only2, :column_names_both

  def initialize(schema1, schema2)
    @schema1 = schema1
    @schema2 = schema2

    get_column_names_diff
  end

  #TODO: Unfinished yet
  def equals?
    return column_names_equals? && primary_keys_equals?
  end

  def column_names_equals?
    return @column_names_only1.empty? && @column_names_only2.empty?
  end

  def primary_keys_equals?
    return @schema1.primary_keys == @schema2.primary_keys
  end

  def primary_keys1
    return @schema1.primary_keys
  end

  def primary_keys2
    return @schema2.primary_keys
  end

  private

    def get_column_names_diff
      column_names1 = @schema1.column_names
      column_names2 = @schema2.column_names
      @column_names_only1 = column_names1 - column_names2
      @column_names_only2 = column_names2 - column_names1 
      @column_names_both  = column_names1 - @column_names_only1
    end
end

class TableSchema
  attr_reader :name, :columns, :primary_keys, :unique_keys, :foreign_keys, :keys
  attr_reader :engine, :auto_increment, :default_charset, :collate, :max_rows, :comment

  DEFAULT_COLUMN_COMMENT_FOR_ID = "RDBMSが生成する一意のID番号"

  def initialize(raw_schema, capitalizes_types=false)
    @name         = nil
    @columns      = Array.new
    @primary_keys = Array.new
    @unique_keys  = Array.new
    @foreign_keys = Array.new
    @keys         = Array.new

    parse_raw_schema(raw_schema.split("\n"), capitalizes_types)
  end

    def parse_raw_schema(lines, capitalizes_types)
      lines.each do |line|
        next if /^\s*$/ =~ line
        parse_raw_line(line, capitalizes_types)
      end

      set_primary_keys_to_columns
      sort_foreign_keys_by_column_order
      set_default_column_comment_for_id
    end
    private :parse_raw_schema

  def column_names
    return @columns.map { |column| column.name }
  end

  def column_names_to_sort
    columns_to_sort = @columns.select { |column| ! column.auto_increment? && ! column.hard_to_sort? }
    return columns_to_sort.map { |column| column.name }
  end

  def difference(other)
    unless other.kind_of?(TableSchema)
      raise ArgumentError.new("Argument other must be a TableSchemaDifference instance")
    end

    return TableSchemaDifference.new(self, other)
  end

  def ==(other)
    return self.columns == other.columns
  end

  def to_s
    schemas = Array.new
    schemas << "TABLE `#{@name}`"
    @columns.each do |column|
      schemas << column.to_s
    end
    @columns.each do |column|
      schemas << "SET options for COLUMN `#{column.name}`: #{column.set_options}" if column.set_options
    end
    schemas << "primary key = `#{@primary_keys.join('`,`')}`" if @primary_keys
    @unique_keys.each do |unique|
      schemas << unique.to_s
    end
    @foreign_keys.each do |foreign|
      schemas << foreign.to_s
    end
    schemas << "engine=#{          @engine          || '(n/a)'}"
    schemas << "default_charset=#{ @default_charset || '(n/a)'}"
    schemas << "collate=#{         @collate         || '(n/a)'}"
    schemas << "max_rows=#{        @max_rows        || '(n/a)'}"
    schemas << "comment=#{         @comment         || '(n/a)'}"
    return schemas.join("\n")
  end

  ROOT_ELEMENT_NAME = 'table'

  def to_xml
    root_element = REXML::Element.new(ROOT_ELEMENT_NAME)
    root_element.add_attribute('name', @name)

    [@columns, @unique_keys, @foreign_keys, @keys].each do |items|
      items.each do |item|
        root_element << item.to_xml
      end
    end

    element_set_options = REXML::Element.new('set_options')
    @columns.each do |column|
      next unless set_options = column.set_options
      element = REXML::Element.new('set_option')
      element.add_attribute('column_name', column.name)
      element.add_text(set_options)
      element_set_options << element
    end
    root_element << element_set_options

    add_table_options_as_xml(root_element)

    return root_element
  end

  private

    def parse_raw_line(line, capitalizes_types)
      if @name.nil?
        @name = get_table_name_at_top(line)
        return
      end
      column_schema = ColumnSchema.parse(line, capitalizes_types)
      if column_schema
        @columns << column_schema
        return
      end
      return if get_key(line)
      get_table_options(line)
    end

    RE_PK = /^\s*PRIMARY KEY\s+\(`([\w`, ]+)`\),?\s*$/

    def get_key(line)
      if m = Regexp.compile(RE_PK).match(line)
        raise DuplicatePrimaryKeyException.new("#{@primary_keys} and #{m[1]}") if @primary_keys.size > 0
        @primary_keys = m[1].split(/`,\s*`/)
        return true
      end
      if key = Key.parse(line)
        (key.unique? ? @unique_keys : @keys) << key
        return true
      end
      if foreign = ForeignKey.parse(line)
        @foreign_keys << foreign
        return true
      end
      return false
    end

    def set_primary_keys_to_columns
      @columns.each do |column|
        column.is_primary_key = true if @primary_keys.include?(column.name)
      end
    end

    def sort_foreign_keys_by_column_order
      map_foreign_keys = Hash.new
      @foreign_keys.each do |fkey|
        map_foreign_keys[fkey.column_name] = fkey
      end
      foreign_key_column_names = map_foreign_keys.keys

      sorted_keys = Array.new
      @columns.each do |column|
        if foreign_key_column_names.include?(column.name)
          sorted_keys << map_foreign_keys[column.name]
        end
      end
      @foreign_keys = sorted_keys
    end

    def set_default_column_comment_for_id
      return if @primary_keys.size > 1
      column = @columns.find { |column| column.name == @primary_keys[0] }
      return if column.nil? || ! column.auto_increment?
      column.comment = DEFAULT_COLUMN_COMMENT_FOR_ID if column.comment_blank?
    end

    RE_TABLE_NAME = /^\s*CREATE TABLE `(\w+)` \(\s*$/

    def get_table_name_at_top(line)
      m = Regexp.compile(RE_TABLE_NAME).match(line)
      raise CannotGetTableNameException.new("in \"#{line}\"") unless m
      return m[1]
    end

    RE_TABLE_OPTIONS = %r!
      ^\s*\)\s+ENGINE=(\w+)
      (?:\s+AUTO_INCREMENT=(\d+))?
      (?:\s+DEFAULT\ CHARSET=(\w+))?
      (?:\s+COLLATE=(\w+))?
      (?:\s+MAX_ROWS=(\d+))?
      (?:\s+COMMENT='(.+)')?\s*$
    !x

    def get_table_options(line)
      m = Regexp.compile(RE_TABLE_OPTIONS).match(line)
      raise CannotGetTableOptionsException.new("in \"#{line}\"") unless m
      @engine          = m[1]
      @auto_increment  = m[2]
      @default_charset = m[3]
      @collate         = m[4]
      @max_rows        = m[5]
      @comment         = m[6]
    end

    def add_table_options_as_xml(root_element)
      element_options = REXML::Element.new('table_options')

      element = REXML::Element.new('engine')
      element.add_text(@engine)
      element_options << element

      element = REXML::Element.new('default_charset')
      element.add_text(@default_charset)
      element_options << element

      element = REXML::Element.new('collate')
      element.add_text(@collate)
      element_options << element

      element = REXML::Element.new('max_rows')
      element.add_text(@max_rows)
      element_options << element

      element = REXML::Element.new('comment')
      cdata = REXML::CData.new(@comment || "")
      element.add(cdata)
      element_options << element

      root_element << element_options
    end
end

class ColumnSchema
  attr_reader :name, :type, :default, :set_options
  attr_accessor :comment

  RE = %r!
    ^\s*`(\w+)`
    \s+(.*?)
    \s*(?:COMMENT\s+'(.*)')?
    \s*,?\s*$
  !x

  def self.parse(line, capitalizes_types)
    m = Regexp.compile(RE).match(line)
    return nil unless m
    name       = m[1]
    definition = m[2]
    comment    = m[3]
    return ColumnSchema.new(name, definition, comment, capitalizes_types)
  end

  def initialize(name, definition, comment, capitalizes_types)
    @name    = name
    @comment = comment
    parse_definition(definition, capitalizes_types)
    @is_primary_key = false
  end

  def not_null?
    return @not_null
  end

  def auto_increment?
    return @auto_increment
  end

  def primary_key?
    return @is_primary_key
  end

  def is_primary_key=(value)
    @is_primary_key = value
  end

  def comment_blank?
    return @comment.nil? || @comment.empty?
  end

  TYPES_HARD_TO_SORT = %w(BLOB MEDIUMBLOB LONGBLOB)

  def hard_to_sort?
    TYPES_HARD_TO_SORT.each do |type_hard|
      return true if @type[0, type_hard.length] == type_hard
    end
    return false
  end

  def ==(other)
    return self.name == other.name && self.type == other.type
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

  def to_xml
    element_column = REXML::Element.new('column')
    element_column.add_attribute('name', @name)
    element_column.add_attribute('primary_key', @is_primary_key)
    element_column.add_attribute('not_null', @not_null)
    element_column.add_attribute('auto_increment', @auto_increment)

    element = REXML::Element.new('type')
    element.add_text(@type)
    element_column << element

    element = REXML::Element.new('default')
    element.add_text(@default)
    element_column << element

    element = REXML::Element.new('comment')
    cdata = REXML::CData.new(@comment || "")
    element.add(cdata)
    element_column << element

    return element_column
  end

  private

    def parse_definition(definition, capitalizes_types)
      @set_options = nil

      terms = definition.split
      is_type_set = /^set\s*\(/i =~ terms[0]
      if capitalizes_types
        is_type_set ? terms[0][0, 3] = 'SET' : terms[0].upcase!
      end
      # Process a type such as "set('volumetic','material balance','d e f')".
      # (Including quoted spaces.)
      if is_type_set
        if terms[0].index(')').nil?
          begin
            terms[0] += ' ' + (term = terms.delete_at(1))
          end until term.index(')')
        end
        @set_options = terms[0]
        @set_options.sub!(/^[^(]*(\([^)]*\)).*$/, "\\1")
        terms[0] = "set"
        terms[0].upcase! if capitalizes_types
      end

      @type = get_type(terms, capitalizes_types)

      begin
        @not_null, @default, @auto_increment = get_null_default_and_auto_increment(terms)
      rescue UnsupportedColumnDefinitionException => evar
        raise UnsupportedColumnDefinitionException.new(evar.message + " in \"#{definition}\"")
      end
    end

    TERMS_TO_SUPPLEMENT_TYPE = %w(unsigned zerofill binary ascii unicode collate utf8_unicode_ci)

    # Return the first term and the following terms included in TERMS_TO_SUPPLEMENT_TYPE, joined by ' '
    def get_type(terms, capitalizes_types)
      type_elements = Array.new
      type_elements << terms.shift
      while terms.size > 0 && TERMS_TO_SUPPLEMENT_TYPE.include?(terms[0])
        term = terms.shift
        term.upcase! if capitalizes_types
        type_elements << term
      end
      return type_elements.join(' ')
    end

    #  [NOT NULL | NULL] [DEFAULT default_value] [AUTO_INCREMENT]
    # "set('cumulative','volumetic','decline','material balance','simulation','etc') default NULL"
    def get_null_default_and_auto_increment(terms)
      not_null = false
      default = nil
      auto_increment = false
      while terms.size > 0
        if terms[0] == 'NOT' && terms[1] == 'NULL'
          not_null = true
          terms.shift; terms.shift
        elsif terms[0] == 'default'
          terms.shift
          default = terms.shift
          if /^'[^']+$/ =~ default # unclosed quotation
            begin
              default += ' ' + (term = terms.shift)
            end until term.index("'")
          end
          if /^'([^']+)'$/ =~ default # removed single quotations
            default = $1
          end
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

class Key
  attr_reader :name, :column_names

  RE = %r!
    ^\s*(UNIQUE\ )?KEY
    \s+`(\w+)`
    \s+\(`([\w`,\ ]+)`\)
    ,?\s*$
  !x

  def self.parse(line)
    m = Regexp.compile(RE).match(line)
    return nil unless m
    is_unique = m[1] && ! (/UNIQUE +/ =~ m[1]).nil?
    name = m[2]
    column_names = m[3].split(/`,\s*`/)
    return Key.new(name, column_names, is_unique)
  end

  def initialize(name, column_names, is_unique)
    @name = name
    @column_names = column_names
    @is_unique = is_unique
  end

  def unique?
    return @is_unique
  end

  def key_name
    return "#{@is_unique ? 'unique_' : ''}key"
  end

  def to_s
    return "#{key_name} `#{name}` (`#{column_names.join('`,`')}`)"
  end

  def to_xml
    element_key = REXML::Element.new(key_name)
    element_key.add_attribute('name', @name)
    element_key.add_attribute('unique', @is_unique)

    @column_names.each do |column_name|
      element = REXML::Element.new('column_name')
      element.add_text(column_name)
      element_key << element
    end

    return element_key
  end
end

class ForeignKey
  attr_reader :name, :column_name, :ref_table_name, :ref_column_name, :on_update, :on_delete

  DEFAULT_ON_UPDATE = "RESTRICT"
  DEFAULT_ON_DELETE = "RESTRICT"

  RE = %r!
    ^\s*CONSTRAINT\s+`(\w+)`
    \s+FOREIGN\ KEY\s+\(`(\w+)`\)
    \s+REFERENCES\s+`(\w+)`\s+\(`(\w+)`\)
    (?:\s+ON\ DELETE\ (\w+\ ?\w+))?
    (?:\s+ON\ UPDATE\ (\w+\ ?\w+))?
    \s*,?\s*$
  !x

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
    return "foreign key `#{@name}` (`#{@column_name}`) refs `#{@ref_table_name}` (`#{@ref_column_name}`)\n" \
         + "    on update #{@on_update} on delete #{@on_delete}"
  end

  def to_xml
    element_key = REXML::Element.new('foreign_key')
    element_key.add_attribute('name', @name)

    element = REXML::Element.new('column_name')
    element.add_text(@column_name)
    element_key << element

    element = REXML::Element.new('reference_table_name')
    element.add_text(@ref_table_name)
    element_key << element

    element = REXML::Element.new('reference_column_name')
    element.add_text(@ref_column_name)
    element_key << element

    element = REXML::Element.new('on_delete')
    element.add_text(@on_delete)
    element_key << element

    element = REXML::Element.new('on_update')
    element.add_text(@on_update)
    element_key << element

    return element_key
  end
end

# Whole data of a specific TABLE
class TableData

  DEFAULT_DELIMITER_WHEN_OUTPUT = "\t"

  def initialize(table_schema, conn, delimiter_out=DEFAULT_DELIMITER_WHEN_OUTPUT)
    @table_schema = table_schema
    @conn = conn
    @delimiter_out = delimiter_out

    @has_been_compared = false
  end

  def table_name
    return @table_schema.name
  end

  def environment
    return @conn.environment
  end

  def identity(is_self=true)
    table_data = is_self ? self : @other
    raise NotComparedYetException.new("Need to call compare() before refering other TableData") unless table_data
    return "TABLE `#{table_data.table_name}` of '#{table_data.environment}'"
  end

  def schema
    return @table_schema
  end

  def to_s_row_values(hash_rows)
    values = Array.new
    @table_schema.column_names.each do |column_name|
      values << hash_rows[column_name]
    end
    return values.join(@delimiter_out)
  end

  def delimiter_out=(value)
    @delimiter_out = value
  end

  # Return a Mysql::Result
  def get_result
    column_names_to_sort = @table_schema.column_names_to_sort
    sql = "SELECT * FROM #{@table_schema.name} ORDER BY #{column_names_to_sort.join(', ')}"
    return @conn.get_query_result(sql)
  end

  def hash_rows_only_in_self
    return hash_rows_only_in_self_or_other(true)
  end

  def hash_rows_only_in_other
    return hash_rows_only_in_self_or_other(false)
  end

  # Return an Array of Hash's with keys of column names and values of data values
  def hash_rows_only_in_self_or_other(is_self=true)
    raise NotComparedYetException.new unless @has_been_compared
    return is_self ? @hash_rows_only_self : @hash_rows_only_other
  end

  def compare(other)
    if self.schema != other.schema
      msg = "Schema differs between #{self.identity} and #{other.identity}"
      raise CannotCompareDueToSchemaDiscrepancyException.new(msg)
    end
    @other = other

    result_self  = self .get_result
    result_other = other.get_result
    @hash_rows_only_self  = Array.new
    @hash_rows_only_other = Array.new
    begin
      hash_row_self  = result_self .fetch_hash
      hash_row_other = result_other.fetch_hash
      until hash_row_self.nil? && hash_row_other.nil?
        cmp = compare_rows(hash_row_self, hash_row_other)
        break if cmp == 0
        if cmp < 0
          @hash_rows_only_self  << hash_row_self
          hash_row_self  = result_self .fetch_hash
        else
          @hash_rows_only_other << hash_row_other
          hash_row_other = result_other.fetch_hash
        end
      end
    end until hash_row_self.nil? && hash_row_other.nil?

    @has_been_compared = true
  end

  def to_s
    result = get_result

    outs = Array.new
    while values = result.fetch_row
      outs << values.join(@delimiter_out)
    end
    outs << "Total of #{result.num_rows} rows"

    return outs.join("\n")
  end

  private

    # Return -1, 0, 1 according to <, ==, >
    def compare_rows(hash_row1, hash_row2)
      return  0 if hash_row1.nil? && hash_row2.nil?
      return -1 if hash_row2.nil?
      return  1 if hash_row1.nil?
      @table_schema.column_names_to_sort.each do |column_name|
        value1 = hash_row1[column_name]
        value2 = hash_row2[column_name]
        next if value1 == value2
        return value1 < value2 ? -1 : 1
      end
      return 0
    end
end


class Schezer

  # config_filename: YAML 形式のデータベース接続情報を含んだファイルのファイル名。
  #                  形式は Rails の config/database.yml と同等。
  #                  次の config_name が指定されなかった場合は YAMLファイルの最上層を探す
  # config_name:     接続情報の名称。Rails の環境名にあたる
  def initialize(argv)
    prepare_command_line_options(argv)

    exit_with_help if argv.empty?
    exit_with_msg("Specify different names for option -e and -g") if @config_name == @config_name2

    @conn = configure(@config_filename, @config_name)
    unless @conn.configuration_suffices?
      exit_with_msg("Cannot read necessary configuration from '#{@config_name}'\n#{self.to_s}")
    end

    @conn2 = configure(@config_filename, @config_name2)
    if (@config_name2 && @conn2.nil?) || (@conn2 && ! @conn2.configuration_suffices?)
      exit_with_msg("Cannot read necessary configuration from '#{@config_name2}'\n#{self.to_s}")
    end

    @argv = argv
  end

  COMMAND_HELPS = [
    "names: Output all the table names",
    "regexp: Output all the table names which match regular expression",
    "raw (table_name|all): Output raw table schema (all for all tables)",
    "table (table_name|all): Output parsed table schema (all for all tables)",
    "xml (table_name|all): Output schema in XML (all for all tables)",
    "count (table_name|all): Output row count of the table (all for all tables)",
    "data table_name: Output data of the table",
  ]

  COMMANDS_NOT_TO_RUN_WITH_TWO_ENVIRONMENTS = [:raw, :xml]

  JOINT_TABLE_NAME_OUTPUTS   = " "
  SPLITTER_TABLE_SCHEMA_OUTPUTS = "#{'=' * 10}\n"

  def execute
    command = @argv.shift
    unless command
      $stderr.puts "No command specified"
      return
    end
    command = command.intern

    next_arg = @argv.shift
    exit_with_msg("Specify a table name or 'all'") unless next_arg
    table_names = next_arg == 'all' ? get_table_names(@conn) : [next_arg]

    if @conn2
      if COMMANDS_NOT_TO_RUN_WITH_TWO_ENVIRONMENTS.include?(command)
        exit_with_msg("Cannot run command '#{command}' with two environments")
      end
      table_names2 = next_arg == 'all' ? get_table_names(@conn2) : [next_arg]
    end

    do_command(command, table_names, table_names2)
  end

  def to_s
    return "host = #{@host}, username = #{@username}, " \
         + "password = #{Schezer.non_empty_string?(@password) ? '*' * 8 : '(none)'}, database = #{@database}, " \
         + "encoding = #{@encoding}"
  end

  private

    def do_command(command, table_names, table_names2)
      case command
      when :names
        if @conn2.nil?
          puts get_table_names(@conn).join(JOINT_TABLE_NAME_OUTPUTS)
        else
          names1 = get_table_names(@conn ).sort
          names2 = get_table_names(@conn2).sort
          compare_table_names_and_print(names1, names2)
        end
      when :regexp
        str_re = table_names[0]
        if @conn2.nil?
          names = get_table_names_with_regexp(@conn, str_re)
          puts names.size == 0 ? '(none)' : names.join(JOINT_TABLE_NAME_OUTPUTS)
        else
          names1 = get_table_names_with_regexp(@conn , str_re).sort
          names2 = get_table_names_with_regexp(@conn2, str_re).sort
          compare_table_names_and_print(names1, names2)
        end
      when :raw, :table
        if @conn2.nil?
          output_schema(table_names, command == :raw)
        else
          compare_table_schemas_and_print(table_names, table_names2)
        end
      when :xml
        output_xml(table_names)
      when :count
        table_names = table_names - (table_names - table_names2) if @conn2
        outs = Array.new
        table_names.each do |table_name|
          s = to_s_row_count(table_name, @conn, @conn2)
          outs << s if s
        end
        puts outs.join("\n")
      when :data
        exit_with_msg("Command 'data' not for multiple tables") if table_names.size > 1

        table_name = table_names[0]
        table_schema = parse_table_schema(table_name, @conn)
        table_data = TableData.new(table_schema, @conn)
        table_data.delimiter_out = @delimiter_field if @delimiter_field
        if @conn2.nil?
          puts table_data
        else
          table_schema2 = parse_table_schema(table_name, @conn2)
          table_data2 = TableData.new(table_schema2, @conn2)
          table_data.compare(table_data2)

          [true, false].each do |is_self|
            print_rows_only_in_either(table_data, is_self)
          end
        end
      else
        exit_with_msg("Unknown command '#{command}'")
      end
    end

    def print_rows_only_in_either(table_data, is_self=true)
      puts "[Rows which appears only in #{table_data.identity(is_self)}]:"
      hash_rows = table_data.hash_rows_only_in_self_or_other(is_self)
      if hash_rows.empty?
        puts "(none)"
      else
        hash_rows.each do |hash_row|
          puts table_data.to_s_row_values(hash_row)
        end
      end
    end

    def to_s_row_count(table_name, conn, conn2=nil)
      row_count  = get_row_count(table_name, conn )
      row_count2 = 0
      if conn2
        row_count2 = get_row_count(table_name, conn2)
        return nil if row_count == row_count2 && ! @verbose
      end
      max_row_count = [1, row_count, row_count2].max
      max_cols = (Math::log10(max_row_count) + 1).to_i
      format = "TABLE `%s`'s COUNT(*) = %#{max_cols}d"

      outs = Array.new
      outs << (sprintf(format, table_name, row_count ) + (conn2 ? " for '#{conn .environment}'" : ""))
      outs << (sprintf(format, table_name, row_count2) +          " for '#{conn2.environment}'") if conn2
      return outs.join("\n")
    end

    # Return nil if VIEW
    def parse_table_schema(name, conn)
      raw_schema = get_raw_table_schema(name, conn)
      return nil unless raw_schema
      ts = TableSchema.new(raw_schema, @capitalizes_types)
      return ts
    end

    def get_table_names(conn)
      sql = "SHOW TABLES"
      result = conn.get_query_result(sql)
      names = Array.new
      result.each do |name|
        next if view?(name, conn)
        names << name[0]
      end
      return names
    end

    def get_table_names_with_regexp(conn, str_re)
      names = Array.new
      get_table_names(conn).each do |name|
        if /#{str_re}/ =~ name
          names << name
        end
      end
      return names
    end

    FIELD_NAME_FOR_VIEW = "View"

    def view?(name, conn)
      result = get_create_table_result(name, conn)
      field_names = result.fetch_fields.map { |field| field.name }
      return field_names.include?(FIELD_NAME_FOR_VIEW)
    end

    # Return nil if VIEW
    def get_raw_table_schema(name, conn)
      result = get_create_table_result(name, conn)
      schema = result.fetch_hash['Create Table']
      return schema
    end

    def get_create_table_result(name, conn)
      sql = "SHOW CREATE TABLE #{name}"
      begin
        result = conn.get_query_result(sql)
      rescue Mysql::Error => evar
        exit_with_msg("Failed to get the schema of TABLE '#{name}'")
      end
      return result
    end

    def get_row_count(name, conn)
      sql = "SELECT COUNT(*) FROM #{name}"
      begin
        result = conn.get_query_result(sql)
      rescue Mysql::Error => evar
        exit_with_msg("Failed to get the row count of TABLE '#{name}'")
      end
      return result.fetch_hash['COUNT(*)'].to_i
    end

    def output_schema(table_names, is_raw)
      outs = Array.new
      table_names.each do |table_name|
        if is_raw
          schema = get_raw_table_schema(table_name, @conn)
        else
          schema = parse_table_schema(table_name, @conn)
        end
        next unless schema
        outs << schema
      end
      puts outs.join("\n" + SPLITTER_TABLE_SCHEMA_OUTPUTS)
    end

    def compare_table_names_and_print(names1, names2)
      names_both = compare_table_names(names1, names2, true)

      outs = to_s_array_to_display_names(names_both, nil, 'tables')
      puts outs.join("\n") unless outs.empty?
    end

    JOINT_COLUMN_NAME_OUTPUTS = " "

    def compare_table_schemas_and_print(names1, names2)
      outs = Array.new
      prints_difference = names1.size > 1 || names1 != names2
      names_both = compare_table_names(names1, names2, prints_difference)
      puts SPLITTER_TABLE_SCHEMA_OUTPUTS if prints_difference && ! names_both.empty?
      names_both.each do |table_name|
        schema1 = parse_table_schema(table_name, @conn )
        schema2 = parse_table_schema(table_name, @conn2)
        next if schema1.nil? || schema2.nil?

        schema_diff = schema1.difference(schema2)

        outs2 = Array.new

        if ! schema_diff.column_names_equals? || @verbose
          column_names_only1 = schema_diff.column_names_only1
          column_names_only2 = schema_diff.column_names_only2
          column_names_both  = schema_diff.column_names_both

          outs2 << "TABLE `#{table_name}`"
          outs2.concat(to_s_array_to_display_names(column_names_only1, @conn .environment, 'columns'))
          outs2.concat(to_s_array_to_display_names(column_names_only2, @conn2.environment, 'columns'))
          outs2.concat(to_s_array_to_display_names(column_names_both , nil               , 'columns'))
        end

        if ! schema_diff.primary_keys_equals? || @verbose
          outs2 << "[Primary keys for '#{@conn .environment}']: (#{schema_diff.primary_keys1.join(', ')})"
          outs2 << "[Primary keys for '#{@conn2.environment}']: (#{schema_diff.primary_keys2.join(', ')})"
        end

        #TODO

        outs << outs2.join("\n") unless outs2.empty?
      end

      puts outs.join("\n" + SPLITTER_TABLE_SCHEMA_OUTPUTS) unless outs.empty?
    end

    # Also return an array of table names which appear in both the arguments.
    def compare_table_names(names1, names2, prints_difference=false)
      names_only1 = names1 - names2
      names_only2 = names2 - names1

      if prints_difference
        outs = Array.new
        outs.concat(to_s_array_to_display_names(names_only1, @conn .environment, 'tables'))
        outs.concat(to_s_array_to_display_names(names_only2, @conn2.environment, 'tables'))
        puts outs.join("\n") unless outs.empty?
      end

      names_both = names1 - names_only1
      return names_both
    end

    def to_s_array_to_display_names(names, environment_name, subject_name)
      where = environment_name ? "only in '#{environment_name}'" : "in both environments"
      outs = Array.new
      outs << "[#{subject_name.capitalize} which appears #{where} (Total of #{names.size})]:"
      outs << (names.empty? ? "(none)" : names.join(JOINT_COLUMN_NAME_OUTPUTS))
      return outs
    end

    XML_INDENT_WHEN_PRETTY = 2

    def output_xml(table_names)
      xml_doc = to_xml
      root_element = xml_doc.root
      table_names.each do |table_name|
        schema = parse_table_schema(table_name, @conn)
        next unless schema
        root_element.add_element(schema.to_xml)
      end
      indent = @is_pretty ? XML_INDENT_WHEN_PRETTY / 2 : -1
      xml_doc.write($stdout, indent)
      puts
    end

    ROOT_ELEMENT_NAME = 'table_schema'

    def to_xml
      xml_doc = REXML::Document.new
      xml_doc.add(REXML::XMLDecl.new(version="1.0", encoding="utf-8"))

      root_element = REXML::Element.new(ROOT_ELEMENT_NAME)
      root_element.add_attribute('host', @host)
      root_element.add_attribute('database', @database)
      xml_doc.add_element(root_element)

      return xml_doc
    end

    def configure(filename, name)
      return nil unless name

      exit_with_usage("Specify DB_config_filename") unless filename
      begin
        yaml = YAML.load_file(filename)
      rescue
        exit_with_msg("Cannot open file '#{filename}'")
      end

      hash_conf = yaml
      hash_conf = hash_conf[name] if name
      return nil unless hash_conf

      hash_conf['environment'] = name
      return DBConnection.new(hash_conf)
    end

    def self.non_empty_string?(*args)
      args.each do |x|
        return false if ! x.kind_of?(String) || x.length == 0
      end
      return true
    end

    COMMAND_OPTIONS_AND_SUBCOMMAND = \
          "-f DB_config_filename -e environment [-g environment_2] [options]" \
        + " command [table_name|all]"

    def exit_with_help
      puts "Usage: #{$0} #{COMMAND_OPTIONS_AND_SUBCOMMAND}"
      puts "command is one of the followings:"
      indent = ' ' * 2
      COMMAND_HELPS.each do |explanation|
        puts sprintf("%s%s\n", indent, explanation)
      end

      exit(0)
    end

    def exit_with_msg(msg=nil, exit_no=1)
      $stderr.puts msg if msg
      exit(exit_no)
    end

    def exit_with_usage(msg=nil, exit_no=1)
      msg_list = Array.new
      msg_list << msg if msg
      msg_list << "Usage: #{$0} #{COMMAND_OPTIONS_AND_SUBCOMMAND}"
      exit_with_msg(msg_list.join("\n"), exit_no)
    end

    def prepare_command_line_options(argv)
      # Default values of options
      @delimiter_field   = nil
      @is_pretty         = false
      @capitalizes_types = false

      @options = Hash.new { |h, k| h[k] = nil }
      opt_parser = OptionParser.new
      opt_parser.on("-d", "--delimiter_field=VALUE") { |v| @delimiter_field   = v }
      opt_parser.on("-f", "--config_file=VALUE"    ) { |v| @config_filename   = v }
      opt_parser.on("-e", "--environment=VALUE"    ) { |v| @config_name       = v }
      opt_parser.on("-g", "--environment_alt=VALUE") { |v| @config_name2      = v }
      opt_parser.on("-v", "--verbose"              ) { |v| @verbose           = true }
      opt_parser.on("--pretty"                     ) { |v| @is_pretty         = true }
      opt_parser.on("--capitalizes_types"          ) { |v| @capitalizes_types = true }
      opt_parser.parse!(argv)
    end

    class DBConnection
      attr_reader :host, :username, :password, :database, :encoding, :environment

      def initialize(hash_conf)
        @host        = hash_conf['host']
        @username    = hash_conf['username']
        @password    = hash_conf['password']
        @database    = hash_conf['database']
        @encoding    = hash_conf['encoding']
        @environment = hash_conf['environment']

        connect
      end

        def connect
          @conn = Mysql.new(@host, @username, @password, @database)
          get_query_result("SET NAMES #{@encoding}")
        end
        private :connect

      def configuration_suffices?
        return Schezer.non_empty_string?(@host, @username, @database)
      end

      def get_query_result(sql)
        return @conn.query(sql)
      end
    end
end


if __FILE__ == $0
  schezer = Schezer.new(ARGV)

  schezer.execute
end


#[EOF]

