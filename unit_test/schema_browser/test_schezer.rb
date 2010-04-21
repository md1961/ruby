
require 'test/unit'

require 'schezer'


class TestSchezer < Test::Unit::TestCase

  BASE_DIR = "#{ENV['HOME']}/ruby/unit_test/schema_browser"
  CONF_FILE = "#{BASE_DIR}/db/schezer_test.yml"

  TABLE_NAMES_DEVEL = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)
  TABLE_NAMES_PROD  = %w(base_unit field fluid reserve reserve_header reservoir unit user)

  def test_get_table_names_from_argv_raise_exception
    no_table_names_devel = %w(field_office reserve_commentary user role)
    schezer = make_schezer_instance(*%w(-e development names))

    no_table_names_devel.each do |table_name|
      msg ="@argv = [\"#{table_name}\"] should have thrown an ExitWithMessageException"
      assert_raise(ExitWithMessageException, msg) do
        schezer.instance_eval do
          @argv = [table_name]
          get_table_names_from_argv(@conn)
        end
      end
    end
  end

    def make_schezer_instance(*args)
      return Schezer.new(['-f', CONF_FILE] + args)
    end
    private :make_schezer_instance

  def test_get_table_names_from_argv
    table_names = call_get_table_names_from_argv(:development)
    assert_equal(TABLE_NAMES_DEVEL, table_names)

    table_names = call_get_table_names_from_argv(:production)
    assert_equal(TABLE_NAMES_PROD , table_names)
  end

    def call_get_table_names_from_argv(environment)
      schezer = make_schezer_instance('-e', environment.to_s, 'names')

      table_names = nil
      schezer.instance_eval do
        @argv = [Schezer::DEFAULT_TABLE_NAME]
        table_names = get_table_names_from_argv(@conn)
      end

      return table_names
    end
    private :call_get_table_names_from_argv

  def test_table_name2str_regexp_raise_exception
    schezer = make_schezer_instance(*%w(-e development names))

    illegal_patterns = %w('abc'de' "fg"hij" !klm!no!)

    illegal_patterns.each do |pattern|
      assert_raise(ExitWithMessageException, "Should have thrown an ExitWithMessageException") do
        schezer.instance_eval do
          table_name2str_regexp(pattern)
        end
      end
    end
  end

  def test_table_name2str_regexp_return_nil
    schezer = make_schezer_instance(*%w(-e development names))

    no_patterns = %w(abc reserve user)

    no_patterns.each do |pattern|
      actual = ''
      schezer.instance_eval do
        actual = table_name2str_regexp(pattern)
      end
      assert_nil(actual, "table_name2str_regexp(\"#{pattern}\") should be nil")
    end
  end

  def test_table_name2str_regexp
    schezer = make_schezer_instance(*%w(-e development names))

    legal_patterns = %w('abcde' "fghij" !klmno! ab* a.b ^ab ab$ ab?)

    legal_patterns.each do |pattern|
      actual = nil
      schezer.instance_eval do
        actual = table_name2str_regexp(pattern)
      end
      assert_not_nil(actual, "table_name2str_regexp(\"#{pattern}\") should be non-nil")
    end
  end

  def test_do_command_raise_exception
    schezer = make_schezer_instance(*%w(-e development names))

    no_commands = [:make, :delete, :remove]

    no_commands.each do |command|
      msg = "do_command(:#{command}, [], []) should have thrown an ExitWithMessageException"
      assert_raise(ExitWithMessageException, msg) do
        schezer.instance_eval do
          do_command(command, [], [])
        end
      end
    end
  end

  def test_to_disp_sql_to_sync_raise_exception
    schezer = make_schezer_instance(*%w(-e development sql_sync))

    assert_raise(ExitWithMessageException, "Should have thrown an ExitWithMessageException") do
      schezer.instance_eval do
        to_disp_sql_to_sync([], [])
      end
    end
  end

  def test_to_disp_sql_to_sync
    schezer = make_schezer_instance(*%w(-e development -g production sql_sync))

    table_names = %w(reserve_header)
    expected = ["INSERT INTO reserve_header VALUES (3, 1, '2002-12-31', 90, 0, '2001-03-01 00:00:00', NULL, 'S', ' 減退見直し');"]
    do_assert_to_disp_sql_to_sync(schezer, table_names, expected)

    table_names = %w(reserve)
    expected = ["INSERT INTO reserve VALUES (5, 3, 1, 6543.21, 1);\nINSERT INTO reserve VALUES (6, 3, 2, 8765.43, 2);"]
    do_assert_to_disp_sql_to_sync(schezer, table_names, expected)

    #TODO: Add more tests (to UPDATE and DELETE)
  end

    def do_assert_to_disp_sql_to_sync(schezer, table_names, expected_sqls)
      actual_sqls = nil
      schezer.instance_eval do
        actual_sqls = to_disp_sql_to_sync(table_names, table_names)
      end
      assert_equal(expected_sqls, actual_sqls)
    end
    private :do_assert_to_disp_sql_to_sync

  def test_value_in_sql
    schezer = make_schezer_instance(*%w(-e development sql_sync))

    column = make_column_schema_mock('id', true)
    actual = nil
    schezer.instance_eval do
      actual = value_in_sql({'id' => nil}, column)
    end
    assert_equal("NULL", actual)

    actual = nil
    schezer.instance_eval do
      actual = value_in_sql({'id' => 23}, column)
    end
    assert_equal(23, actual)

    column = make_column_schema_mock('type', false)
    actual = nil
    schezer.instance_eval do
      actual = value_in_sql({'type' => 'field'}, column)
    end
    assert_equal("'field'", actual)
  end

  def test_make_values_for_sql_insert
    schezer = make_schezer_instance(*%w(-e development sql_sync))

    column_id   = make_column_schema_mock('id'  , true)
    column_a_id = make_column_schema_mock('a_id', true)
    column_b_id = make_column_schema_mock('b_id', true)
    columns = [column_id, column_a_id, column_b_id]
    hash_row = {'id' => 2, 'a_id' => 3, 'b_id' => 5}
    actual = nil
    schezer.instance_eval do
      actual = make_values_for_sql_insert(hash_row, columns)
    end
    assert_equal([2, 3, 5], actual)

    column_id   = make_column_schema_mock('id'  , true)
    column_type = make_column_schema_mock('type', false)
    column_name = make_column_schema_mock('name', false)
    column_alt  = make_column_schema_mock('alt' , false)
    columns = [column_id, column_type, column_name, column_alt]
    hash_row = {'id' => 23, 'type' => 'field', 'name' => 'Ghawar', 'alt' => nil}
    actual = nil
    schezer.instance_eval do
      actual = make_values_for_sql_insert(hash_row, columns)
    end
    assert_equal([23, "'field'", "'Ghawar'", "NULL"], actual)
  end

    def make_column_schema_mock(name, is_numerical)
      mock = Object.new
      mock.instance_variable_set(:@name  , name)
      mock.instance_variable_set(:@is_num, is_numerical)
      class << mock
        def name
          @name
        end
        def numerical_type?
          @is_num
        end
      end

      return mock
    end
    private :make_column_schema_mock

  def test_to_disp_table_data_with_one_env
    schezer = make_schezer_instance(*%w(-e development data))

    table_names = %w(reserve)
    actual = nil
    schezer.instance_eval do
      actual = to_disp_table_data(table_names)
    end
    expected = [
        "1\t1\t1\t1234.56\t1\n" \
      + "2\t1\t2\t3456.78\t2\n" \
      + "3\t2\t1\t5678.90\t1\n" \
      + "4\t2\t2\t7890.12\t2\n" \
      + "Total of 4 rows"
    ]
    assert_equal(expected, actual, "Data of TABLE `reserve`")

    table_names = %w(base_unit field)
    actual = nil
    schezer.instance_eval do
      actual = to_disp_table_data(table_names)
    end
    expected = [
        "1\tKL\n" \
      + "2\tm3\n" \
      + "4\tSCF\n" \
      + "3\tSTB\n" \
      + "Total of 4 rows",
        "14\tHigashi-Niigata\t東新潟\t\t\t\t840\n" \
      + "20\tIwafune-Oki\t岩船沖\t\t\t\t2100\n" \
      + "3\tSarukawa\t申川\t\t\t\t320\n" \
      + "1\tYufutsu\t勇払\t\t\t\t140\n" \
      + "Total of 4 rows"
    ]
    assert_equal(expected, actual, "Data of TABLE `base_unit` and `field`")
  end

  def test_to_disp_table_data_with_two_envs
    schezer = make_schezer_instance(*%w(-e development -g production data))

    table_names = %w(fluid)
    actual = nil
    schezer.instance_eval do
      actual = to_disp_table_data(table_names)
    end
    msg = "to_disp_table_data() with TABLE `fluid` with two environments should return an emtpy array"
    assert(actual.empty?, msg)

    table_names = %w(reserve)
    actual = nil
    schezer.instance_eval do
      actual = to_disp_table_data(table_names)
    end
    expected = [
        "TABLE `reserve`:\n" \
      + "[Pair of rows different but same with unique keys ('development', then 'production')\n" \
      + "(none)\n" \
      + "[Rows which appears only in development]:\n" \
      + "(none)\n" \
      + "[Rows which appears only in production]:\n" \
      + "5\t3\t1\t6543.21\t1\n" \
      + "6\t3\t2\t8765.43\t2"
    ]
    assert_equal(expected, actual, "Data comparison of TABLE `base_unit` and `field`")
  end

  #TODO: Test to_s_pairs_with_unique_key_same(table_data)
  #TODO: Test to_s_rows_only_in_either(table_data, is_self=true)

  def test_to_disp_row_count_with_one_env
    schezer = make_schezer_instance(*%w(-e development data))

    table_name = 'reserve'
    actual = nil
    schezer.instance_eval do
      actual = to_disp_row_count(table_name, @conn)
    end
    expected = "TABLE `reserve`'s COUNT(*) = 4"
    assert_equal(expected, actual, "Row count of TABLE `#{table_name}`")
  end

  def test_to_disp_row_count_with_two_envs
    schezer = make_schezer_instance(*%w(-e development -g production data))

    table_name = 'base_unit'
    actual = nil
    schezer.instance_eval do
      actual = to_disp_row_count(table_name, @conn, @conn2)
    end
    assert_nil(actual, "Row count comparison of TABLE `#{table_name}`")

    table_name = 'reserve'
    actual = nil
    schezer.instance_eval do
      actual = to_disp_row_count(table_name, @conn, @conn2)
    end
    expected = \
        "TABLE `reserve`'s COUNT(*) = 4 for 'development'\n" \
      + "TABLE `reserve`'s COUNT(*) = 6 for 'production'"
    assert_equal(expected, actual, "Row count comparison of TABLE `#{table_name}`")
  end

  # def parse_table_schema(name, conn)
  def test_parse_table_schema
    schezer = make_schezer_instance(*%w(-e development data))

    table_name = 'non_existence'
    msg = "ExitWithMessageException should have thrown with a TABLE which does not exist"
    assert_raise(ExitWithMessageException, msg) do
      schezer.instance_eval do
        actual = parse_table_schema(table_name, @conn)
      end
    end

    table_name = 'fluid'
    actual = nil
    schezer.instance_eval do
      actual = parse_table_schema(table_name, @conn)
    end
    h_expected = {
      :name => 'fluid', :primary_keys => %w(fluid_id), :max_rows => nil, :engine => 'InnoDB',
      :default_charset => 'utf8', :collate => nil, :comment => nil
    }
    assert_table_schema(h_expected, actual)
    array_of_h_expected = [
      {:name => 'fluid_id', :type => 'int(10) unsigned', :not_null => true, :default => nil,
       :is_primary_key => true, :auto_increment => true, :set_options => nil},
      {:name => 'fluid', :type => 'varchar(20)', :not_null => true, :default => "''",
       :is_primary_key => false, :auto_increment => false, :set_options => nil},
      {:name => 'fluid_zen', :type => 'varchar(20)', :not_null => true, :default => "''",
       :is_primary_key => false, :auto_increment => false, :set_options => nil},
      {:name => 'fluid_order', :type => 'int(10)', :not_null => true, :default => nil,
       :is_primary_key => false, :auto_increment => false, :set_options => nil},
    ]
    assert_column_schema_of_table_schema(array_of_h_expected, actual)
    array_of_h_expected = [
      {:name => 'fluid_id' , :column_names => %w(fluid_id) , :is_unique => true},
      {:name => 'fluid'    , :column_names => %w(fluid)    , :is_unique => true},
      {:name => 'fluid_zen', :column_names => %w(fluid_zen), :is_unique => true},
    ]
    assert_unique_keys_of_table_schema(array_of_h_expected, actual)
  end

    def assert_table_schema(h_expected, schema)
      assert_not_nil(schema, "TableSchema should be non-null")
      assert_equal(h_expected[:name]           , schema.name           , "table name")
      assert_equal(h_expected[:primary_keys]   , schema.primary_keys   , "primary keys")
      assert_equal(h_expected[:max_rows]       , schema.max_rows       , "max rows")
      assert_equal(h_expected[:engine]         , schema.engine         , "engine")
      assert_equal(h_expected[:default_charset], schema.default_charset, "default charset")
      assert_equal(h_expected[:collate]        , schema.collate        , "collate")
      assert_equal(h_expected[:comment]        , schema.comment        , "comment")
    end
    private :assert_table_schema

    def assert_column_schema_of_table_schema(array_of_h_expected, schema)
      assert_not_nil(schema, "TableSchema should be non-null")
      columns = schema.columns

      actual_column_names   = columns.map { |column| column.name }
      expected_column_names = array_of_h_expected.map { |h| h[:name] }
      assert_equal(expected_column_names, actual_column_names, "column names")

      columns.zip(array_of_h_expected) do |column, h_expected|
        name = column.name
        assert_equal(h_expected[:name]          , name                  , "column name")
        assert_equal(h_expected[:type]          , column.type           , "data type of COLUMN `#{name}`")
        assert_equal(h_expected[:not_null]      , column.not_null?      , "not null of COLUMN `#{name}`")
        assert_equal(h_expected[:default]       , column.default        , "default of COLUMN `#{name}`")
        assert_equal(h_expected[:is_primary_key], column.primary_key?   , "primary_key? of COLUMN `#{name}`")
        assert_equal(h_expected[:auto_increment], column.auto_increment?, "auto_increment? of COLUMN `#{name}`")
        assert_equal(h_expected[:set_options]   , column.set_options    , "set_options of COLUMN `#{name}`")
      end
    end
    private :assert_column_schema_of_table_schema

    def assert_unique_keys_of_table_schema(array_of_h_expected, schema)
      assert_not_nil(schema, "TableSchema should be non-null")
      unique_keys = schema.unique_keys

      actual_key_names   = unique_keys.map { |key| key.name }
      expected_key_names = array_of_h_expected.map { |h| h[:name] }
      assert_equal(expected_key_names, actual_key_names, "key names")

      unique_keys.zip(array_of_h_expected) do |key, h_expected|
        name = key.name
        assert_equal(h_expected[:name]        , name            , "key name")
        assert_equal(h_expected[:column_names], key.column_names, "column names of key `#{name}`")
        assert_equal(h_expected[:is_unique]   , key.unique?     , "unique? of key `#{name}`")
      end
    end
    private :assert_unique_keys_of_table_schema
end

