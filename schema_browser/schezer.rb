#! /usr/bin/env ruby
# vi: set fileencoding=utf-8 :

require 'mysql'
require 'yaml'
require 'optparse'
require 'rexml/document'

require 'kuma'
require 'table_on_cui'


# 例外クラス
class CannotGetTableNameException                < Exception; end
class CannotGetTableOptionsException             < Exception; end
class UnsupportedColumnDefinitionException       < Exception; end
class UnsupportedViewDefinitionException         < Exception; end
class DuplicatePrimaryKeyException               < Exception; end
class SchemaDiscrepancyException                 < Exception; end
class NotComparedYetException                    < Exception; end
class NoPrimaryKeyException                      < Exception; end
class MultipleRowsExpectingUniqueResultException < Exception; end
class IllegalStateException                      < Exception; end


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
    return @schema1.primary_keys.sort == @schema2.primary_keys.sort
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

class AbstractTableSchema
  attr_reader :name, :columns

  RE_VIEW_DEFINITION = /\A\s*CREATE\s+.*VIEW\s+`[\w_]+`\.`([\w_]+)`\s+AS\s+(.+)\z/i

  def self.instance(raw_schema, terminal_width, capitalizes_types=false)
    if RE_VIEW_DEFINITION =~ raw_schema
      return ViewSchema.new($1, $2, terminal_width, capitalizes_types)
    end
    return TableSchema.new(raw_schema, terminal_width, capitalizes_types)
  end

  def column_names
    return @columns.map { |column| column.name }
  end

  def column_names_to_sort(includes_auto_increment=false)
    return Array.new
  end
end

class ViewSchema < AbstractTableSchema
  attr_reader :tables, :where

  def initialize(name, select_statement, terminal_width, capitalizes_types=false)
    @name = name
    parse_raw_view_schema(select_statement, capitalizes_types)
  end

    RE_VIEW_AS_SELECT = /\A\s*SELECT\s+(.*\S)\s+FROM\s+(\S.*\S)(?:\s+WHERE\s+(\S.*\S))?\s*\z/i

    def parse_raw_view_schema(select_statement, capitalizes_types)
      unless RE_VIEW_AS_SELECT =~ select_statement
        raise UnsupportedViewDefinitionException.new("Cannot parse 'AS SELECT' in VIEW definition: #{select_statement}")
      end

      column_str = $1
      table_str  = $2
      @where     = $3

      @columns = column_str.split(/,\s*/).map { |s| ColumnInView.new(s) }
      @tables  = table_str .split(/,\s*/).map { |s| TableInView .new(s) }
    end
    private :parse_raw_view_schema

  def to_s
    outs = Array.new

    outs << "VIEW `#{@name}`"

    outs << to_columns_table

    return outs.join("\n")
  end

  INDEX_NAME      = "name"
  INDEX_SOURCE    = "source"
  INDEX_TRUE_NAME = "true name"
  INDEXES = [INDEX_NAME, INDEX_SOURCE, INDEX_TRUE_NAME].freeze

  def to_columns_table
    map_indexes = Hash.new
    INDEXES.each do |index|
      map_indexes[index] = index
    end

    table_items = Array.new
    @columns.each do |column|
      table_items << to_map_table_items(column)
    end

    table = TableOnCUI.new(INDEXES, lambda { |x| Kuma::StrUtil.displaying_length(x.to_s) })
    table.set_data(table_items)
    return table.to_table
  end

    def to_map_table_items(column)
      map_items = Hash.new
      INDEXES.each do |index|
        column.instance_eval do
          map_items[index] = instance_variable_get("@#{index.gsub(/ /, '_')}")
        end
      end

      return map_items
    end
    private :to_map_table_items
end

# column / table identification in VIEW definition
class ItemInView
  attr_reader :name, :source, :true_name
  # `resman2`.`completion`.`reservoir_id` AS `reservoir_id` であれば
  # @name = "reservoir_id", @source = "`resman2`.`completion`", @true_name = "reservoir_id" となる

  RE_VIEW_ITEM_NAME = /(`\w[\w_.`]+\w`)\.`([\w_]+)`(?:\s+AS\s+`([\w_]+)`)?/

  def initialize(definition)
    unless RE_VIEW_ITEM_NAME =~ definition
      raise UnsupportedViewDefinitionException.new("Cannot parse as column nor table in VIEW definition: #{item}")
    end

    @source    = $1
    @true_name = $2
    @name      = $3
  end

  def to_s
    name = @name || @true_name
    return "#{name} (#{true_name} FROM #{@source})"
  end
end

class ColumnInView < ItemInView

  def numerical_type?
    return true if /_?id\z/ =~ name
    return false
  end
end

class TableInView  < ItemInView
end

class TableSchema < AbstractTableSchema
  # @primary_keys は String、
  # @unique_keys と @keys は Key、
  # @foreign_keys は ForeignKey
  # のそれぞれ配列
  attr_reader :primary_keys, :unique_keys, :foreign_keys, :keys
  attr_reader :engine, :auto_increment, :default_charset, :collate, :max_rows, :comment

  DEFAULT_COLUMN_COMMENT_FOR_ID = "RDBMSが生成する一意のID番号"

  def initialize(raw_schema, terminal_width, capitalizes_types=false)
    unless raw_schema.kind_of?(String)
      raise ArgumentError.new("Argument raw_schema must be a String")
    end
    unless terminal_width.kind_of?(Fixnum)
      raise ArgumentError.new("Argument terminal_width must be a Fixnum")
    end

    @name         = nil
    @columns      = Array.new
    @primary_keys = Array.new
    @unique_keys  = Array.new
    @foreign_keys = Array.new
    @keys         = Array.new

    @terminal_width = terminal_width

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

  def columns_with_primary_key
    return @columns.select { |column| @primary_keys.include?(column.name) }
  end

  def has_columns_hard_to_sort?
    @columns.each do |column|
      return true if column.hard_to_sort?
    end
    return false
  end

  def column_names_to_sort(includes_auto_increment=false)
    columns_to_sort = @columns       .select { |column| ! column.hard_to_sort?   }
    columns_to_sort = columns_to_sort.select { |column| ! column.auto_increment? } unless includes_auto_increment
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
    schemas << "TABLE `#{@name}`: Comment \"#{@comment || '(n/a)'}\""

    schemas << to_columns_table

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

  INDEX_NAME    = "Field"
  INDEX_TYPE    = "Type"
  INDEX_NULL    = "Null"
  INDEX_KEYS    = "Key"
  INDEX_DEFAULT = "Default"
  INDEX_EXTRA   = "Extra"
  INDEX_COMMENT = "Comment"
  INDEXES = [INDEX_NAME, INDEX_TYPE, INDEX_NULL, INDEX_KEYS, INDEX_DEFAULT, INDEX_EXTRA, INDEX_COMMENT].freeze

  def to_columns_table
    map_indexes = Hash.new
    INDEXES.each do |index|
      map_indexes[index] = index
    end

    table_items = Array.new
    @columns.each do |column|
      table_items << to_map_table_items(column)
    end

    indexes = INDEXES - (all_columns_comments_blank? ? [INDEX_COMMENT] : [])
    table = TableOnCUI.new(indexes, lambda { |x| Kuma::StrUtil.displaying_length(x.to_s) })
    table.set_data(table_items)
    if table.width <= @terminal_width
      return table.to_table
    else
      table.hide(INDEX_COMMENT)
      table0 = table.to_table
      table.hide(:all)
      table.show(INDEX_NAME, INDEX_COMMENT)
      table1 = table.to_table
      return [table0, table1].join("\n")
    end
  end

  private

    def all_columns_comments_blank?
      return @columns.all? { |column| column.comment_blank? }
    end

    ITEMS_NOT_NULL = 'NO'
    ITEMS_AUTO_INCREMENT = 'auto inc.'

    def to_map_table_items(column)
      map_items = Hash.new

      map_items[INDEX_NAME] = column.name
      map_items[INDEX_TYPE] = column.type
      map_items[INDEX_NULL] = column.not_null? ? ITEMS_NOT_NULL : ''
      keys = Array.new
      keys << 'PRI' if @primary_keys.include?(column.name)
      keys << 'FK'  if @foreign_keys.map {|key| key.name }.include?(column.name)
      map_items[INDEX_KEYS] = keys.join(',')
      map_items[INDEX_DEFAULT] = column.default || ''
      map_items[INDEX_EXTRA]   = column.auto_increment? ? ITEMS_AUTO_INCREMENT : ''
      map_items[INDEX_COMMENT] = column.comment || ""

      return map_items
    end

    def parse_raw_line(line, capitalizes_types)
      unless @name
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

    RE_PK = /^\s*PRIMARY KEY\s+\(`([\w`, ]+)`\),?\s*$/i

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
      return if all_columns_comments_blank?
      column = @columns.find { |column| column.name == @primary_keys[0] }
      return if column.nil? || ! column.auto_increment?
      column.comment = DEFAULT_COLUMN_COMMENT_FOR_ID if column.comment_blank?
    end

    RE_TABLE_NAME = /^\s*CREATE +(?:TABLE|.*VIEW) +(?:`[^`]+`\.)?`(\w+)` +/i

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
    !xi

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
    parse_definition(definition, capitalizes_types) if definition
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
  TYPES_TOO_LONG_TO_DISPLAY = %w(TEXT MEDIUMTEXT LONGTEXT)

  def hard_to_sort?
    return type?(TYPES_HARD_TO_SORT)
  end

  def too_long_to_display?
    return type?(TYPES_TOO_LONG_TO_DISPLAY)
  end

  NUMERICAL_TYPES = %w(NUMERIC DECIMAL INTEGER SMALLINT TINYINT FLOAT REAL DOUBLE INT DEC)

  def numerical_type?
    return type?(NUMERICAL_TYPES)
  end

    def type?(types)
      types.each do |type|
        return true if @type[0, type.length].upcase == type.upcase
      end
      return false
    end
    private :type?

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
        type_elements << term
      end

      if capitalizes_types
        type_elements.each do |element|
          element.upcase! if element
        end
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
        term0 = terms[0] && terms[0].upcase
        term1 = terms[1] && terms[1].upcase
        if term0 == 'NULL'
          not_null = false
          terms.shift
        elsif term0 == 'NOT' && term1 == 'NULL'
          not_null = true
          terms.shift; terms.shift
        elsif term0 == 'DEFAULT'
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
        elsif term0 == 'AUTO_INCREMENT'
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
    is_unique = ! m[1].nil?
    name = m[2]
    column_names = m[3].split(/`,\s*`/)
    return Key.new(name, column_names, is_unique)
  end

  def initialize(name, column_names, is_unique)
    @name         = name
    @column_names = column_names
    @is_unique    = is_unique
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

  #TODO: :column_name => column_names, use \s+\(`([\w`,\ ]+)`\) in RE
  #  and :ref_column_name => ref_column_names ??

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
    @name            = name
    @column_name     = column_name
    @ref_table_name  = ref_table_name
    @ref_column_name = ref_column_name
    @on_delete       = on_delete
    @on_update       = on_update
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

# 特定の DBテーブルの全レコードを取得するためのクラス
class TableData

  DEFAULT_DELIMITER_WHEN_OUTPUT = "\t"

  def initialize(table_schema, conn, delimiter_out=DEFAULT_DELIMITER_WHEN_OUTPUT)
    @table_schema = table_schema
    @conn = conn
    @delimiter_out = delimiter_out

    @has_been_compared = false

    @row_count = nil
  end

  # 返り値: Mysql::Result のインスタンス
  def get_result(includes_auto_increment=false)
    column_names_to_sort = @table_schema.column_names_to_sort(includes_auto_increment)
    sql = "SELECT * FROM #{@table_schema.name}"
    sql += " ORDER BY #{column_names_to_sort.join(', ')}" unless column_names_to_sort.empty?
    result = @conn.get_query_result(sql)
    @row_count = result.num_rows
    return result
  end

  # 主キーが引数と等しいレコードを返す。見つからないときは nil を返す
  def find_hash_row_by_primary_key(ref_hash_row)
    primary_keys = @table_schema.primary_keys
    if primary_keys.nil? || primary_keys.empty?
      raise NoPrimaryKeyException.new
    end

    column_names_self = @table_schema.column_names.sort
    column_names_arg  = ref_hash_row .keys        .sort
    unless column_names_self == column_names_arg
      msg = "self(#{column_names_self.inspect}) vs argument(#{column_names_arg.inspect})"
      raise SchemaDiscrepancyException.new(msg)
    end

    cond_primary_keys = Array.new
    primary_keys.each do |primary_key|
      ref_value = ref_hash_row[primary_key]
      ref_value = "'#{ref_value}'" if ref_value.kind_of?(String)
      cond_primary_keys << "#{primary_key} = #{ref_value}"
    end
    sql = "SELECT * FROM #{@table_schema.name} WHERE #{cond_primary_keys.join(' AND ')}"
    result = @conn.get_query_result(sql)
    raise MultipleRowsExpectingUniqueResultException.new(sql) if result.num_rows > 1
    return result.fetch_hash
  end

  def table_name(is_self=true)
    check_other_table_data unless is_self
    return is_self ? @table_schema.name : @other.table_name
  end

  def database(is_self=true)
    check_other_table_data unless is_self
    return is_self ? @conn.database : @other.database
  end

  def environment(is_self=true)
    check_other_table_data unless is_self
    return is_self ? @conn.environment : @other.environment
  end

  def identity(is_self=true)
    check_other_table_data unless is_self
    table_data = is_self ? self : @other
    return "TABLE `#{table_data.table_name}` of DB `#{table_data.database}`"
  end

    def check_other_table_data
      raise NotComparedYetException.new("Need to call compare() before refering other TableData") unless @other
    end
    private :check_other_table_data

  def schema
    return @table_schema
  end

  def delimiter_out=(value)
    @delimiter_out = value
  end

  def hash_rows_only_in_self
    return hash_rows_only_in_self_or_other(true)
  end

  def hash_rows_only_in_other
    return hash_rows_only_in_self_or_other(false)
  end

  # 返り値: カラム名をキー、カラム値を値とする Hash の配列
  def hash_rows_only_in_self_or_other(is_self=true)
    raise NotComparedYetException.new unless @has_been_compared
    return is_self ? @hash_rows_only_self : @hash_rows_only_other
  end

  def pair_hash_rows_with_unique_key_same
    raise NotComparedYetException.new unless @has_been_compared
    return @pair_hash_rows_with_unique_key_same
  end

  # メソッド compare() の結果、値の異なるレコードが見つからなかったか、
  # 否かを評価する
  def different_rows_empty?
    return hash_rows_only_in_self             .empty? \
        && hash_rows_only_in_other            .empty? \
        && pair_hash_rows_with_unique_key_same.empty?
  end

  def compare(other, unique_key_equalize=false)
    if self.schema != other.schema
      msg = "Table schema differs between #{self.identity} and #{other.identity}"
      raise SchemaDiscrepancyException.new(msg)
    end
    @other = other

    result_self  = self .get_result
    result_other = other.get_result
    @hash_rows_only_self  = Array.new
    @hash_rows_only_other = Array.new
    @pair_hash_rows_with_unique_key_same = Array.new
    begin
      hash_row_self  = result_self .fetch_hash
      hash_row_other = result_other.fetch_hash
      until hash_row_self.nil? && hash_row_other.nil?
        cmp = compare_rows(hash_row_self, hash_row_other)
        break if cmp == 0
        if unique_key_equalize && compare_rows_with_unique_keys_only(hash_row_self, hash_row_other) == 0
          @pair_hash_rows_with_unique_key_same << [hash_row_self, hash_row_other]
          hash_row_self  = result_self .fetch_hash
          hash_row_other = result_other.fetch_hash
        elsif cmp < 0
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

  LENGTH_TRUNCATE_FOR_LONG_TEXT = 20
  MARK_TRUNCATED = '.' * 6

  def to_s_row_values(hash_rows)
    values = Array.new
    @table_schema.columns.each do |column|
      value = column.hard_to_sort? ? "(Type:#{column.type})" : hash_rows[column.name]
      value = value[0, LENGTH_TRUNCATE_FOR_LONG_TEXT] + MARK_TRUNCATED if value && column.too_long_to_display?
      values << value
    end
    return values.join(@delimiter_out)
  end

  # このメソッドを呼ぶ前に get_result() を明示して呼ぶか、あるいは
  # to_s(), to_yaml(), to_table() のいずれかを呼ばなければならない
  def row_count
    raise IllegalStateException.new("get_result() was not called yet") unless @row_count
    return @row_count
  end

  def to_s
    result = get_result

    outs = Array.new
    while hash_rows = result.fetch_hash
      outs << to_s_row_values(hash_rows)
    end
    outs << "Total of #{result.num_rows} rows"

    return outs.join("\n")
  end

  INDENT_IN_YAML = 2

  def to_yaml
    outs = Array.new
    outs << "#{@table_schema.name} :"

    result = get_result(includes_auto_increment=true)
    columns = @table_schema.columns
    while hash_rows = result.fetch_hash
      is_first_column = true
      columns.each do |column|
        next if column.hard_to_sort? || column.too_long_to_display?
        indent = (is_first_column ? '-' : ' ') + ' ' * (INDENT_IN_YAML - 1)
        outs << "#{indent}#{column.name} : #{hash_rows[column.name]}"
        is_first_column = false
      end
    end

    return outs.join("\n")
  end

  def to_table(terminal_width, record_limit)
    result = get_result(includes_auto_increment=true)
    table_items = Array.new
    count = 0
    while hash_rows = result.fetch_hash
      table_items << hash_rows
      count += 1
      break if record_limit && count >= record_limit
    end

    return nil if table_items.empty?

    indexes = @table_schema.column_names
    map_indexes = Hash.new
    indexes.each do |index|
      map_indexes[index] = index
    end

    table = TableOnCUI.new(indexes, lambda { |x| Kuma::StrUtil.displaying_length(x.to_s) })
    table.nil_display = "NULL"
    table.set_data(table_items)
    @table_schema.columns.each do |column|
      table.set_align_right(column.name) if column.numerical_type?
    end

    if table.width <= terminal_width
      return table.to_table
    else
      #TODO: Implement properly
      raise "Not supported yet"
      table.hide(INDEX_COMMENT)
      table0 = table.to_table
      table.hide(:all)
      table.show(INDEX_NAME, INDEX_COMMENT)
      table1 = table.to_table
      return [table0, table1].join("\n")
    end
  end

  private

    # Return -1, 0, 1 according to <, ==, >
    def compare_rows(hash_row1, hash_row2, column_names_to_sort_with=@table_schema.column_names_to_sort)
      return  0 if hash_row1.nil? && hash_row2.nil?
      return -1 if hash_row2.nil?
      return  1 if hash_row1.nil?
      column_names_to_sort_with.each do |column_name|
        value1 = hash_row1[column_name]
        value2 = hash_row2[column_name]
        next if value1 == value2
        return -1 if value1.nil?
        return  1 if value2.nil?
        return value1 < value2 ? -1 : 1
      end
      return 0
    end

    def compare_rows_with_unique_keys_only(hash_row1, hash_row2)
      @table_schema.unique_keys.each do |unique_key|
        cmp = compare_rows(hash_row1, hash_row2, unique_key.column_names)
        return cmp unless cmp == 0
      end
      return 0
    end
end


class ExitWithMessageException < Exception; end
class InfrastructureException  < Exception; end

class Schezer

  DEFAULT_CONFIG_FILENAME = 'config/database.yml'
  DEFAULT_CONFIG_ENV_NAME = 'development'

  def initialize(argv)
    prepare_command_line_options(argv)
    @config_filename = DEFAULT_CONFIG_FILENAME unless @config_filename
    @config_name     = DEFAULT_CONFIG_ENV_NAME unless @config_name

    exit_with_help("No command specified") if argv.empty?

    begin
      @conn = configure(@config_filename, @config_name)
      unless @conn && @conn.configuration_suffices?
        raise ExitWithMessageException.new("Cannot read necessary configuration from '#{@config_name}'\n#{self.to_s}")
      end

      raise ExitWithMessageException.new("Specify different names for option -e and -g") if @config_name == @config_name2

      @conn2 = configure(@config_filename, @config_name2)
      if (@config_name2 && @conn2.nil?) || (@conn2 && ! @conn2.configuration_suffices?)
        raise ExitWithMessageException.new("Cannot read necessary configuration from '#{@config_name2}'\n#{self.to_s}")
      end
    rescue ExitWithMessageException => e
      exit_with_msg(e.message)
    end

    @argv = argv
  end

  ALL_TABLES = 'all'

  SPC_ALL_T = ' ' * ALL_TABLES.length
  COMMAND_HELPS = [
    "names    : Output table names",
    "raw      : Output raw table schema (Not allowed with -g)",
    "table    : Output parsed table schema",
    "xml      : Output schema in XML (Not allowed with -g)",
    "columns  : Output column names (Not allowed with -g, for now)",
    "count    : Output row count of the table",
    "data     : Output data of the table (Need table name(s) specified)",
    "yaml     : Output data of the table in YAML format (Need table name(s) specified)",
    "fixture  : Output data of the table in YAML format for Rails fixture (Need table name(s) specified)",
    "sql_sync : Generate SQL's to synchronize data of '-e' to '-g'",
  ]

  COMMANDS_NOT_TO_RUN_WITH_TWO_ENVIRONMENTS   = [:raw, :xml, :columns]
  COMMANDS_NOT_TO_RUN_WITH_NO_TABLE_SPECIFIED = [:data, :yaml, :fixture]
  COMMANDS_NOT_TO_RUN_WITH_VIEW_ONLY_OPTION   = []
  DEFAULT_TABLE_NAME = ALL_TABLES

  JOINT_TABLE_NAME_OUTPUTS = "\n"

  SPLITTER_LENGTH = 50
  SPLITTER_TABLE_SCHEMA_OUTPUTS = "#{'=' * SPLITTER_LENGTH}\n"

  def execute
    command = @argv.shift
    exit_with_msg("No command specified") unless command

    command = command.intern

    if @conn2 && COMMANDS_NOT_TO_RUN_WITH_TWO_ENVIRONMENTS.include?(command)
      exit_with_msg("Cannot run command '#{command}' with two environments")
    end
    if @argv.empty? && COMMANDS_NOT_TO_RUN_WITH_NO_TABLE_SPECIFIED.include?(command)
      exit_with_msg("Cannot run command '#{command}' with no table name specified")
    end
    if @view_only && COMMANDS_NOT_TO_RUN_WITH_VIEW_ONLY_OPTION.include?(command)
      exit_with_msg("Cannot run command '#{command}' with command line option -w(--view_only)")
    end

    @argv << DEFAULT_TABLE_NAME if @argv.empty?
    begin
      table_names, table_names2 = get_both_table_names_from_argv
      do_command(command, table_names, table_names2)
    rescue ExitWithMessageException => e
      exit_with_msg(e.message)
    end
  end

  def close_connections
    begin
      @conn .close if @conn
    rescue
    end
    begin
      @conn2.close if @conn2
    rescue
    end
  end

  def to_s
    return "host = #{@host}, username = #{@username}, " \
         + "password = #{Kuma::StrUtil.non_empty_string?(@password) ? '*' * 8 : '(none)'}, database = #{@database}, " \
         + "encoding = #{@encoding}"
  end

  private

    def get_both_table_names_from_argv
      #TODO: Basically unneccessary.  Delete?
      raise RuntimeError.new("@argv is impossiblly empty") if @argv.empty?

      table_names  = get_table_names_from_argv(@conn )
      table_names2 = get_table_names_from_argv(@conn2) if @conn2

      @argv.clear

      return table_names, table_names2
    end

    def get_table_names_from_argv(conn)
      all_table_names = get_table_names(conn)
      if @argv.size == 1 && @argv[0] == ALL_TABLES
        return all_table_names
      end

      table_names = @argv.dup
      table_names_expanded = Array.new
      non_existing_table_names = Array.new
      table_names.each do |table_name|
        if str_re = table_name2str_regexp(table_name)
          table_names_expanded.concat(get_table_names_with_regexp(conn, str_re))
        elsif ! all_table_names.include?(table_name)
          non_existing_table_names << table_name
        else
          table_names_expanded << table_name
        end
      end
      if non_existing_table_names.size > 0
        raise ExitWithMessageException.new(
                "No table in '#{conn.environment}' with name(s) of `#{non_existing_table_names.join('`, `')}`")
      end
      return table_names_expanded.uniq
    end

    MARKER_FOR_REGEXP = %w(* . ^ $ ? |)
    RE_LITERAL_REGEXP = /^([^\w])(.+)\1$/

    def table_name2str_regexp(table_name)
      if RE_LITERAL_REGEXP =~ table_name
        c_quote = $1
        str_re  = $2
        if str_re.index(c_quote)
          raise ExitWithMessageException.new("Illegal table name regexp '#{table_name}' (quote mark in quote)")
        end
        return str_re
      end
      MARKER_FOR_REGEXP.each do |marker|
        return table_name if table_name.index(marker)
      end
      return nil
    end

    def do_command(command, table_names, table_names2)
      outs = Array.new
      joint = "\n" + SPLITTER_TABLE_SCHEMA_OUTPUTS

      case command
      when :names
        unless @conn2
          outs = table_names.sort
          joint = JOINT_TABLE_NAME_OUTPUTS
        else
          names1 = table_names .sort
          names2 = table_names2.sort
          outs = to_disp_table_name_comparison(names1, names2)
          joint = "\n"
        end
      when :raw, :table
        if @conn2.nil?
          outs = to_disp_schema(table_names, command == :raw)
        else
          outs = to_disp_table_schema_comparison(table_names, table_names2)
        end
      when :xml
        xml_doc = to_xml(table_names)
        formatter = @is_pretty ? REXML::Formatters::Pretty .new(XML_INDENT_WHEN_PRETTY) \
                               : REXML::Formatters::Default.new
        formatter.write(xml_doc, $stdout)
        puts
      when :columns
        outs = to_disp_column_names(table_names)
      when :count
        unless @conn2
          num_rows_per_table = 10
          Kuma::ArrayUtil.split(table_names, num_rows_per_table).each do |sub_table_names|
            outs << to_table_row_count(sub_table_names, @conn)
          end
        else
          table_names = table_names - (table_names - table_names2)
          table_names.each do |table_name|
            next if row_count_equal?(table_name, @conn, @conn2) && ! @verbose
            outs << to_table_row_count_comparison(table_name, @conn, @conn2)
          end
        end
        joint = "\n"
      when :data
        outs = to_disp_table_data(table_names, table_names2)
        joint = "\n\n" unless @conn2
      when :sql_sync
        outs = to_disp_sql_to_sync(table_names, table_names2)
      when :yaml
        outs = to_disp_table_data_in_yaml(table_names)
        joint = "\n"
      when :fixture
        outs = [to_rails_fixture(table_names)]
      else
        raise ExitWithMessageException.new("Unknown command '#{command}'")
      end

      puts outs.join(joint) unless outs.empty?
    end

    # @conn の DB を @conn2 の DB に同期されるための SQL を生成する
    def to_disp_sql_to_sync(table_names, table_names2)
      unless @conn2
        raise ExitWithMessageException.new("Specify synchronization destination environment with option '-g'")
      end

      outs, table_names_both = compare_table_names(table_names, table_names2)
      table_names_both.each do |table_name|
        table_schema  = parse_table_schema(table_name, @conn )
        table_schema2 = parse_table_schema(table_name, @conn2)
        next if table_schema.has_columns_hard_to_sort?
        table_data  = TableData.new(table_schema , @conn )
        table_data2 = TableData.new(table_schema2, @conn2)
        table_data.compare(table_data2, unique_key_equalize = true)

        next if table_data.different_rows_empty?

        outs2 = Array.new

        outs2 << "TABLE `#{table_name}`:" if @verbose
        outs2.concat(to_disp_sql_insert_to_sync(table_data, table_schema))
        outs2.concat(to_disp_sql_update_to_sync(table_data, table_schema))

        outs << outs2.join("\n")
      end

      return outs
    end

    def to_disp_sql_insert_to_sync(table_data, table_schema)
      outs = Array.new

      hash_rows = table_data.hash_rows_only_in_other
      unless hash_rows.empty?
        hash_rows.each do |hash_row|
          has_single_primary_key = table_schema.primary_keys.size == 1
          original_hash_row = table_data.find_hash_row_by_primary_key(hash_row)

          index_id = nil
          table_schema.columns.each_with_index do |column, index|
            value = hash_row[column.name]
            if has_single_primary_key && original_hash_row && column.auto_increment?
              index_id = index
              break
            end
          end

          values = make_values_for_sql_insert(hash_row, table_schema.columns)
          values[index_id] = 0 if index_id

          outs << "INSERT INTO #{table_schema.name} VALUES (#{values.join(', ')});"
          if index_id && @verbose
            original_values = make_values_for_sql_insert(original_hash_row, table_schema.columns)
            outs << "((#{original_values.join(', ')}) exists in '#{@conn.environment}')"
          end
        end
      end

      return outs
    end

    #TODO: Add to_disp_sql_delete_to_sync()

    def to_disp_sql_update_to_sync(table_data, table_schema)
      outs = Array.new

      column_names_without_primary_key = table_schema.column_names - table_schema.primary_keys
      columns_without_primary_key = table_schema.columns.select do |column|
        column_names_without_primary_key.include?(column.name)
      end

      pair_hash_rows = table_data.pair_hash_rows_with_unique_key_same
      unless pair_hash_rows.empty?
        pair_hash_rows.each do |hash_row1, hash_row2|
          wheres_pk = Array.new
          table_schema.columns_with_primary_key.each do |column|
            wheres_pk << "#{column.name} = #{value_in_sql(hash_row1, column)}"
          end

          setters = Array.new
          columns_without_primary_key.each do |column|
            next if hash_row1[column.name] == hash_row2[column.name]
            setters << "#{column.name} = #{value_in_sql(hash_row2, column)}"
          end

          outs << "UPDATE #{table_schema.name} SET #{setters.join(', ')} WHERE #{wheres_pk.join(' AND ')};"
          if @verbose
            values_overwritten = make_values_for_sql_insert(hash_row1, table_schema.columns)
            outs << "(Overwriting (#{values_overwritten.join(', ')}) in '#{@conn.environment}')"
          end
        end
      end

      return outs
    end

    # hash_row: カラム名をキー、カラム値を値とする Hash で１レコードを表したもの
    # columns: ColumnSchema の配列
    def make_values_for_sql_insert(hash_row, columns)
      values = Array.new
      columns.each do |column|
        values << value_in_sql(hash_row, column)
      end
      return values
    end

    def value_in_sql(hash_row, column)
      value = hash_row[column.name]
      if value.nil?
        return 'NULL'
      elsif column.numerical_type?
        return value
      end
      return "'#{value}'"
    end

    def to_disp_table_data_in_yaml(table_names)
      outs = Array.new
      table_names.each do |table_name|
        table_schema = parse_table_schema(table_name, @conn)
        table_data = TableData.new(table_schema, @conn)
        outs << table_data.to_yaml
      end
      return outs
    end

    INDENT_IN_FIXTURE = ' ' * 2

    def to_rails_fixture(table_names)
      str_yaml = to_disp_table_data_in_yaml(table_names).join("\n")

      outs = Array.new
      ret_hash = Hash.new
      YAML.load(str_yaml).each do |table_name, rows|
        table_schema = parse_table_schema(table_name, @conn)
        primary_key_names = table_schema.columns_with_primary_key.map { |column| column.name }
        if primary_key_names.empty?
          raise ExitWithMessageException.new(
                  "It's not supported yet to create fixtures for TABLE `#{table_name}` without primary keys")
        end

        outs << "#{table_name} :"
        rows.each do |hash_row|
          pk_values = primary_key_names.map { |column_name| hash_row[column_name] }
          row_label = "id_#{pk_values.join('_')}".gsub(/\s/, '_')
          outs << "#{INDENT_IN_FIXTURE}#{row_label}:"
          table_schema.column_names.each do |column_name|
            outs << "#{INDENT_IN_FIXTURE * 2}#{column_name}: #{hash_row[column_name]}"
          end
        end
      end

      return outs.join("\n")
    end

    NO_DATA_DISPLAY = "(No data)"
    FORMAT_ROW_COUNT = "(Total of %d records)"

    def to_disp_table_data(table_names, table_names2=nil)
      table_names2 = table_names.dup unless table_names2
      unless @conn2
        table_names_both = table_names
        outs = Array.new
      else
        outs, table_names_both = compare_table_names(table_names, table_names2)
      end

      is_multiple_tables = table_names.size > 1
      table_names_both.each do |table_name|
        outs2 = Array.new

        table_schema = parse_table_schema(table_name, @conn)
        table_data = TableData.new(table_schema, @conn)
        table_data.delimiter_out = @delimiter_field if @delimiter_field
        unless @conn2
          table_display = table_data.to_table(@terminal_width, @record_limit)
          table_display = NO_DATA_DISPLAY if table_display.nil? && @verbose
          if table_display
            outs2 << "TABLE `#{table_name}`" << table_display
            row_count = table_data.row_count
            row_count_display = sprintf(FORMAT_ROW_COUNT, row_count)
            outs2 << row_count_display if row_count > 0
          end
        else
          table_schema2 = parse_table_schema(table_name, @conn2)
          table_data2 = TableData.new(table_schema2, @conn2)
          table_data.compare(table_data2, @unique_key_equalize)

          next if ! @verbose && table_data.hash_rows_only_in_self             .empty? \
                             && table_data.hash_rows_only_in_other            .empty? \
                             && table_data.pair_hash_rows_with_unique_key_same.empty?
          outs2 << "TABLE `#{table_name}`:"
          outs2 << to_s_pairs_with_unique_key_same(table_data)
          [true, false].each do |is_self|
             outs2 << to_s_rows_only_in_either(table_data, is_self)
          end
        end

        outs << outs2.join("\n") unless outs2.empty?
      end

      return outs
    end

    NO_ROWS = "(none)"
    SPLITTER_PAIR_OF_TABLE_ROWS = '-' * SPLITTER_LENGTH

    def to_s_pairs_with_unique_key_same(table_data)
      outs = Array.new

      env_self  = table_data.database(true )
      env_other = table_data.database(false)
      index = "[Pair of rows different but same with unique keys (DB `#{env_self}`, then DB `#{env_other}`)"
      pair_hash_rows = table_data.pair_hash_rows_with_unique_key_same
      if pair_hash_rows.empty?
        outs << NO_ROWS
      else
        pair_hash_rows.each do |hash_row_self, hash_row_other|
          outs << SPLITTER_PAIR_OF_TABLE_ROWS
          outs << table_data.to_s_row_values(hash_row_self )
          outs << table_data.to_s_row_values(hash_row_other)
        end
      end

      return [index] + outs
    end

    def to_s_rows_only_in_either(table_data, is_self=true)
      outs = Array.new

      outs << "[Rows which appears only in DB `#{table_data.database(is_self)}`]:"
      hash_rows = table_data.hash_rows_only_in_self_or_other(is_self)
      if hash_rows.empty?
        outs << NO_ROWS
      else
        hash_rows.each do |hash_row|
          outs << table_data.to_s_row_values(hash_row)
        end
      end

      return outs
    end

    def to_table_row_count(table_names, conn)
      indexes = %w(Table Rows)
      table_items = Array.new
      table_names.each do |table_name|
        row_count = get_row_count(table_name, conn)
        table_items << {'Table' => table_name, 'Rows' => row_count}
      end

      table = TableOnCUI.new(indexes)
      table.set_data(table_items)
      return table.to_table
    end

    def to_table_row_count_comparison(table_name, conn, conn2)
      indexes = %w(Table Database Rows)
      table_items = Array.new
      [conn, conn2].each do |conn|
        row_count = get_row_count(table_name, conn)
        name = conn == conn2 ? '' : table_name
        table_items << {'Table' => name, 'Database' => conn.database, 'Rows' => row_count}
      end

      table = TableOnCUI.new(indexes)
      table.set_data(table_items)
      return table.to_table
    end

    # Not used.  Being deprecated...
    def to_disp_row_count(table_name, conn, conn2=nil)
      row_count = get_row_count(table_name, conn)
      row_count2 = 0
      if conn2
        row_count2 = get_row_count(table_name, conn2)
        return nil if row_count == row_count2 && ! @verbose
      end
      max_row_count = [1, row_count, row_count2].max
      max_cols = (Math::log10(max_row_count) + 1).to_i
      format = "TABLE `%s`'s COUNT(*) = %#{max_cols}d"
      
      for_env  = ""
      for_env2 = nil
      if conn2
        for_env = " for DB `#{conn.database}`"
        if row_count == row_count2
          for_env = " for both"
        else
          for_env2 = " for DB `#{conn2.database}`"
        end
      end

      outs = Array.new
      outs << (sprintf(format, table_name, row_count ) + for_env )
      outs << (sprintf(format, table_name, row_count2) + for_env2) if for_env2

      return outs.join("\n")
    end

    def parse_table_schema(name, conn)
      raw_schema = get_raw_table_schema(name, conn)
      return nil unless raw_schema
      ts = AbstractTableSchema.instance(raw_schema, @terminal_width, @capitalizes_types)
      return ts
    end

    def get_table_names(conn)
      sql = "SHOW TABLES"
      result = conn.get_query_result(sql)

      names = Array.new
      result.each do |one_element_array_of_name|
        unless one_element_array_of_name.size == 1
          raise "Unexpected non-one-element-array from Mysql::Result (#{one_element_array_of_name.inspect})"
        end

        name = one_element_array_of_name.first
        next if view?(name, conn) ^ @view_only
        names << name
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

    # Return nil if (-w && TABLE) || (no -w && VIEW)
    def get_raw_table_schema(name, conn)
      result = get_create_table_result(name, conn)
      h_result = result.fetch_hash
      schema = h_result[@view_only ? 'Create View' : 'Create Table']
      return schema
    end

    def get_create_table_result(name, conn)
      raise ArgumentError.new("Argument name must be non-null") unless name

      sql = "SHOW CREATE TABLE #{name}"
      begin
        result = conn.get_query_result(sql)
      rescue Mysql::Error => evar
        raise InfrastructureException.new("Failed to get the schema of TABLE '#{name}' due to Mysql::Error('#{evar}')")
      end
      return result
    end

    def get_row_count(table_name, conn)
      sql = "SELECT COUNT(*) FROM #{table_name}"
      begin
        result = conn.get_query_result(sql)
      rescue Mysql::Error => evar
        raise InfrastructureException.new("Failed to get the row count of TABLE '#{table_name}'")
      end
      return result.fetch_hash['COUNT(*)'].to_i
    end

    def row_count_equal?(table_name, conn, conn2)
      row_count  = get_row_count(table_name, conn )
      row_count2 = get_row_count(table_name, conn2)
      return row_count == row_count2
    end

    def to_disp_schema(table_names, is_raw)
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
      return outs
    end

    def to_disp_column_names(table_names)
      outs = Array.new
      is_multiple_tables = table_names.size > 1
      table_names.each do |table_name|
        outs2 = Array.new
        schema = parse_table_schema(table_name, @conn)
        outs2 << "TABLE `#{table_name}`" if is_multiple_tables
        schema.columns.each do |column|
          outs2 << column.name
        end
        outs << outs2.join("\n")
      end
      return outs
    end

    def to_disp_table_name_comparison(names1, names2)
      outs, table_names_both = compare_table_names(names1, names2)
      outs.concat(to_s_array_to_display_names(table_names_both, nil, 'tables'))
      return outs
    end

    JOINT_COLUMN_NAME_OUTPUTS = " "

    def to_disp_table_schema_comparison(names1, names2)
      outs = Array.new
      outs_diff, table_names_both = compare_table_names(names1, names2)
      outs << outs_diff.join("\n") if names1.size > 1 || names1 != names2

      table_names_both.each do |table_name|
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
          outs2.concat(to_s_array_to_display_names(column_names_only1, @conn .database, 'columns'))
          outs2.concat(to_s_array_to_display_names(column_names_only2, @conn2.database, 'columns'))
          outs2.concat(to_s_array_to_display_names(column_names_both , nil               , 'columns'))
        end

        if ! schema_diff.primary_keys_equals? || @verbose
          outs2 << "[Primary keys for DB `#{@conn .database}`]: (#{schema_diff.primary_keys1.join(', ')})"
          outs2 << "[Primary keys for DB `#{@conn2.database}`]: (#{schema_diff.primary_keys2.join(', ')})"
        end

        #TODO: More diff output might be comming

        outs << outs2.join("\n") unless outs2.empty?
      end

      return outs
    end

    # 引数 names1、および names2 のそれぞれにしか現れない名称を示す表示文字列と、
    # 両方の引数に現れる名称の文字列配列とからなる、要素数２の配列を返す
    #TODO: あるいは返り値の１つは別メソッドで取得するようにするか
    def compare_table_names(names1, names2)
      names_only1 = names1 - names2
      names_only2 = names2 - names1

      outs_diff = Array.new
      outs_diff.concat(to_s_array_to_display_names(names_only1, @conn .database, 'tables'))
      outs_diff.concat(to_s_array_to_display_names(names_only2, @conn2.database, 'tables'))

      names_both = names1 - names_only1
      return outs_diff, names_both
    end

    def to_s_array_to_display_names(names, database_name, subject_name)
      outs = Array.new
      return outs if ! @verbose && names.empty?

      where = database_name ? "only in DB `#{database_name}`" : "in both databases"
      outs << "[#{subject_name.capitalize} which appears #{where} (Total of #{names.size})]:"
      outs << (names.empty? ? "(none)" : names.join(JOINT_COLUMN_NAME_OUTPUTS))

      return outs
    end

    XML_INDENT_WHEN_PRETTY = 2

    def to_xml(table_names)
      xml_doc = initialize_xml_doc
      root_element = xml_doc.root
      table_names.each do |table_name|
        schema = parse_table_schema(table_name, @conn)
        next unless schema
        root_element.add_element(schema.to_xml)
      end
      return xml_doc
    end

    ROOT_ELEMENT_NAME = 'table_schema'

    def initialize_xml_doc
      xml_doc = REXML::Document.new
      xml_doc.add(REXML::XMLDecl.new(version="1.0", encoding="utf-8"))

      root_element = REXML::Element.new(ROOT_ELEMENT_NAME)
      root_element.add_attribute('host', @host)
      root_element.add_attribute('database', @database)
      xml_doc.add_element(root_element)

      return xml_doc
    end

    # filename: YAML 形式のデータベース接続情報を含んだファイルのファイル名。
    #           形式は Rails の config/database.yml と同等。
    #           次の config_name が指定されなかった場合は YAMLファイルの最上層を探す
    # name:     接続情報の名称。Rails の環境名にあたる
    def configure(filename, name)
      return nil unless name
      raise ExitWithMessageException.new("Specify DB_config_filename") unless filename

      begin
        yaml = YAML.load_file(filename)
      rescue
        raise ExitWithMessageException.new("Cannot open file '#{filename}'")
      end

      hash_conf = yaml
      hash_conf = hash_conf[name] if name
      return nil unless hash_conf

      hash_conf['environment'] = name
      return DBConnection.new(hash_conf)
    end

    COMMAND_OPTIONS_AND_SUBCOMMAND = \
          "-f DB_config_filename -e environment [-g environment_2] [options] command [table_name(s)|all]"

    def exit_with_help(msg=nil)
      close_connections

      puts msg if msg
      puts
      puts @opt_parser.help

      exit(0)
    end

    def exit_with_msg(msg=nil, exit_no=1)
      close_connections

      $stderr.puts msg if msg
      exit(exit_no)
    end

    def exit_with_usage(msg=nil, exit_no=1)
      outs = Array.new
      outs << msg if msg
      outs << "Usage: #{$0} #{COMMAND_OPTIONS_AND_SUBCOMMAND}"
      exit_with_msg(outs.join("\n"), exit_no)
    end

    DEFAULT_TERMINAL_WIDTH = 120

    DESC_H  = "Print this message and quit"
    DESC_D  = "Delimiter of output for command 'data' (Default is a 'tab')"
    DESC_F  = "Database connection configuration YAML file (Format of config/database.yml in Rails)"
    DESC_E  = "Database connection name (Environment name in Rails)"
    DESC_G  = "Second database connection name for comparison with -e"
    DESC_V  = "Verbose output"
    DESC_W  = "Include view(s)"
    DESC_CT = "Capitalize COLUMN data types of TABLE schema"
    DESC_LM = "Maximum number of records to display"
    DESC_PR = "Pretty indented XML outputs"
    DESC_TW = "Terminal column width to display (default is #{DEFAULT_TERMINAL_WIDTH})"
    DESC_UK = "Regard two records equal and output together if the unique key values are equal"

    def prepare_command_line_options(argv)
      # コマンドラインオプションのデフォルト値
      @delimiter_field     = nil
      @config_name2        = nil
      @terminal_width      = DEFAULT_TERMINAL_WIDTH
      @view_only           = false
      @record_limit        = nil
      @is_pretty           = false
      @capitalizes_types   = false
      @unique_key_equalize = false

      @options = Hash.new { |h, k| h[k] = nil }
      @opt_parser = OptionParser.new
      put_banner(@opt_parser)

      @opt_parser.on("-h", "--help"                 , DESC_H ) { puts @opt_parser.help; exit(0) }

      @opt_parser.on("-d", "--delimiter_field=VALUE", DESC_D ) { |v| @delimiter_field = v }
      @opt_parser.on("-f", "--config_file=VALUE"    , DESC_F ) { |v| @config_filename = v }
      @opt_parser.on("-e", "--environment=VALUE"    , DESC_E ) { |v| @config_name     = v }
      @opt_parser.on("-g", "--environment_alt=VALUE", DESC_G ) { |v| @config_name2    = v }
      @opt_parser.on("-v", "--verbose"              , DESC_V ) { |v| @verbose             = true   }
      @opt_parser.on("-w", "--view_only"            , DESC_W ) { |v| @view_only           = true   }
      @opt_parser.on("--capitalizes_types"          , DESC_CT) { |v| @capitalizes_types   = true   }
      @opt_parser.on("--limit=VALUE"                , DESC_LM) { |v| @record_limit        = v.to_i }
      @opt_parser.on("--pretty"                     , DESC_PR) { |v| @is_pretty           = true   }
      @opt_parser.on("--terminal_width=VALUE"       , DESC_TW) { |v| @terminal_width      = v.to_i }
      @opt_parser.on("--unique_key_equalize"        , DESC_UK) { |v| @unique_key_equalize = true   }

      @opt_parser.parse!(argv)
    end

    def put_banner(opt_parser)
      command = File.basename($0)

      banners = Array.new
      banners << "Usage: #{command} #{COMMAND_OPTIONS_AND_SUBCOMMAND}"
      banners << "command is one of the followings ('#{ALL_TABLES}' or no table name for all tables):"
      indent = ' ' * 2
      COMMAND_HELPS.each do |explanation|
        banners << indent + explanation
      end

      opt_parser.banner = banners.join("\n")
    end

    # データベースの接続情報を受け取って、データベースに接続し、
    # Mysql のインスタンスを保持するクラス
    class DBConnection
      attr_reader :host, :username, :password, :database, :encoding, :environment

      def initialize(hash_conf)
        @host        = hash_conf['host']
        @username    = hash_conf['username']
        @password    = hash_conf['password']
        @database    = hash_conf['database']
        @encoding    = hash_conf['encoding']
        @environment = hash_conf['environment']

        @conn = connect
        get_query_result("SET NAMES #{@encoding}")
      end

        def connect
          return Mysql.new(@host, @username, @password, @database)
        end
        private :connect

      def configuration_suffices?
        return Kuma::StrUtil.non_empty_string?(@host, @username, @database)
      end

      # 返り値: Mysql::Result のインスタンス
      def get_query_result(sql)
        return @conn.query(sql)
      end
    end
end


if __FILE__ == $0
  schezer = Schezer.new(ARGV)

  begin
    schezer.execute
  ensure
    schezer.close_connections
  end
end


#[EOF]

