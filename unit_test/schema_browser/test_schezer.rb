# vi: set fileencoding=utf-8 :

require 'test/unit'

require 'schezer'


class TestSchezer < Test::Unit::TestCase

  BASE_DIR = "#{ENV['HOME']}/ruby/unit_test/schema_browser"
  CONF_FILE = "#{BASE_DIR}/db/schezer_test.yml"

  TABLE_NAMES_DEVEL = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)
  TABLE_NAMES_PROD  = %w(base_unit field fluid reserve reserve_header reservoir unit user)

  # ===== Test class Schezer =====

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

    column_id   = make_column_schema_mock('id'  , true )
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

    def make_column_schema_mock(name, is_numerical, type='type')
      mock = Object.new
      mock.instance_variable_set(:@name  , name)
      mock.instance_variable_set(:@type  , type)
      mock.instance_variable_set(:@is_num, is_numerical)
      class << mock
        def name
          @name
        end
        def type
          @type
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
    actual_lines = actual.join("\n").split("\n")
    expected_lines = [
      "TABLE `reserve`",
      "+--------------+------------+----------+---------+---------+",
      "| synthetic_id | reserve_id | fluid_id | reserve | unit_id |",
      "+--------------+------------+----------+---------+---------+",
      "|            1 |          1 |        1 | 1234.56 |       1 |",
      "|            2 |          1 |        2 | 3456.78 |       2 |",
      "|            3 |          2 |        1 | 5678.90 |       1 |",
      "|            4 |          2 |        2 | 7890.12 |       2 |",
      "+--------------+------------+----------+---------+---------+",
      "(Total of 4 records)",
    ]
    assert_in_lines(expected_lines, actual_lines, "Data in TABLE `reserve`")

    table_names = %w(base_unit field)
    actual = nil
    schezer.instance_eval do
      actual = to_disp_table_data(table_names)
    end
    actual_lines = actual.join("\n").split("\n")
    expected_lines = [
      "TABLE `base_unit`",
      "+--------------+-----------+",
      "| base_unit_id | base_unit |",
      "+--------------+-----------+",
      "|            1 | KL        |",
      "|            2 | m3        |",
      "|            3 | STB       |",
      "|            4 | SCF       |",
      "+--------------+-----------+",
      "(Total of 4 records)",
      "TABLE `field`",
      "+----------+-----------------+-----------+-----------------+------------+--------------+-------------+",
      "| field_id | field           | field_zen | date_field_aban | date_added | date_removed | field_north |",
      "+----------+-----------------+-----------+-----------------+------------+--------------+-------------+",
      "|        1 | Yufutsu         | 勇払      | NULL            | NULL       | NULL         |         140 |",
      "|        3 | Sarukawa        | 申川      | NULL            | NULL       | NULL         |         320 |",
      "|       14 | Higashi-Niigata | 東新潟    | NULL            | NULL       | NULL         |         840 |",
      "|       20 | Iwafune-Oki     | 岩船沖    | NULL            | NULL       | NULL         |        2100 |",
      "+----------+-----------------+-----------+-----------------+------------+--------------+-------------+",
      "(Total of 4 records)",
    ]
    assert_in_lines(expected_lines, actual_lines, "Data of TABLE `base_unit` and `field`")
  end

    def assert_in_lines(expected_lines, actual_lines, message=nil)
      assert_equal(expected_lines.size, actual_lines.size, message && "#{message} (No. of lines)")
      line_no = 1
      expected_lines.zip(actual_lines) do |expected, actual|
        [expected, actual].each do |line|
          line.gsub!(/(AUTO_INCREMENT=)(\d+)/i, '\\1')
        end
        assert_equal(expected, actual, message && "#{message} (line ##{line_no})")
        line_no += 1
      end
    end
    private :assert_in_lines

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
    actual_lines = actual.join("\n").split("\n")
    expected_lines = [
      "TABLE `reserve`:",
      "[Pair of rows different but same with unique keys (DB `schezer_test`, then DB `schezer_test2`)",
      "(none)",
      "[Rows which appears only in DB `schezer_test`]:",
      "(none)",
      "[Rows which appears only in DB `schezer_test2`]:",
      "5\t3\t1\t6543.21\t1",
      "6\t3\t2\t8765.43\t2",
    ]
    assert_in_lines(expected_lines, actual_lines, "Data comparison of TABLE `base_unit` and `field`")
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
        "TABLE `reserve`'s COUNT(*) = 4 for DB `schezer_test`\n" \
      + "TABLE `reserve`'s COUNT(*) = 6 for DB `schezer_test2`"
    assert_equal(expected, actual, "Row count comparison of TABLE `#{table_name}`")
  end

  # def parse_table_schema(name, conn)
  def test_parse_table_schema_with_non_existing_table
    schezer = make_schezer_instance(*%w(-e development data))

    table_name = 'non_existence'
    msg = "InfrastructureException should have thrown with a TABLE which does not exist"
    assert_raise(InfrastructureException, msg) do
      schezer.instance_eval do
        actual = parse_table_schema(table_name, @conn)
      end
    end
  end

  def test_parse_table_schema_with_table_reserve
    schezer = make_schezer_instance(*%w(-e development data))

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
      {:name => 'fluid_id', :type => 'int(10) unsigned', :not_null => true, :default => nil, :is_primary_key => true,
       :auto_increment => true, :set_options => nil, :comment => "RDBMSが生成する一意のID番号"},
      {:name => 'fluid', :type => 'varchar(20)', :not_null => true, :default => "''", :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "全角文字を入力しないこと"},
      {:name => 'fluid_zen', :type => 'varchar(20)', :not_null => true, :default => "''", :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "なるだけ全角文字のみ入力すること"},
      {:name => 'fluid_order', :type => 'int(10)', :not_null => true, :default => nil, :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
    ]
    assert_column_schema_of_table_schema(array_of_h_expected, actual)
    array_of_h_expected = [
      {:name => 'fluid_id' , :column_names => %w(fluid_id) , :is_unique => true},
      {:name => 'fluid'    , :column_names => %w(fluid)    , :is_unique => true},
      {:name => 'fluid_zen', :column_names => %w(fluid_zen), :is_unique => true},
    ]
    assert_unique_keys_of_table_schema(array_of_h_expected, actual)
  end

  def test_parse_table_schema_with_table_field
    schezer = make_schezer_instance(*%w(-e development data))

    table_name = 'field'
    actual = nil
    schezer.instance_eval do
      actual = parse_table_schema(table_name, @conn)
    end
    h_expected = {
      :name => 'field', :primary_keys => %w(field_id), :max_rows => nil, :engine => 'InnoDB',
      :default_charset => 'utf8', :collate => nil, :comment => nil
    }
    assert_table_schema(h_expected, actual)
    array_of_h_expected = [
      {:name => 'field_id', :type => 'int(10) unsigned', :not_null => true, :default => nil, :is_primary_key => true,
       :auto_increment => true, :set_options => nil, :comment => "RDBMSが生成する一意のID番号"},
      {:name => 'field', :type => 'varchar(40)', :not_null => true, :default => "''", :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "全角文字を入力しないこと"},
      {:name => 'field_zen', :type => 'varchar(40)', :not_null => true, :default => "''", :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "なるだけ全角文字のみ入力すること"},
      {:name => 'date_field_aban', :type => 'date', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "採収終了となった日付"},
      {:name => 'date_added', :type => 'date', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
      {:name => 'date_removed', :type => 'date', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
      {:name => 'field_north', :type => 'int(10) unsigned', :not_null => true, :default => '0', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "北に位置するほど小さい値になる"},
    ]
    assert_column_schema_of_table_schema(array_of_h_expected, actual)
    array_of_h_expected = [
      {:name => 'field_id' , :column_names => %w(field_id) , :is_unique => true},
      {:name => 'field'    , :column_names => %w(field)    , :is_unique => true},
    ]
    assert_unique_keys_of_table_schema(array_of_h_expected, actual)
  end

  def test_parse_table_schema_with_table_reserve_header
    schezer = make_schezer_instance(*%w(-e development data))

    table_name = 'reserve_header'
    actual = nil
    schezer.instance_eval do
      actual = parse_table_schema(table_name, @conn)
    end
    h_expected = {
      :name => 'reserve_header', :primary_keys => %w(reserve_id), :max_rows => nil, :engine => 'InnoDB',
      :default_charset => 'utf8', :collate => nil, :comment => "埋蔵量のヘッダテーブル"
    }
    assert_table_schema(h_expected, actual)
    array_of_h_expected = [
      {:name => 'reserve_id', :type => 'int(10) unsigned', :not_null => true, :default => nil, :is_primary_key => true,
       :auto_increment => true, :set_options => nil, :comment => "RDBMSが生成する一意のID番号"},
      {:name => 'reservoir_id', :type => 'int(10) unsigned', :not_null => true, :default => '0', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
      {:name => 'date_reserve', :type => 'date', :not_null => true, :default => '0000-00-00', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "鉱量の日付"},
      {:name => 'possibility', :type => 'int(10) unsigned', :not_null => true, :default => '0', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "実現確率"},
      {:name => 'is_by_completion', :type => 'tinyint(1) unsigned zerofill', :not_null => true, :default => '0',
       :is_primary_key => false, :auto_increment => false, :set_options => nil,
       :comment => "鉱量データとして 0 であれば reserve、1 であれば reserve_by_completion を使う"},
      {:name => 'datetime_input', :type => 'datetime', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "入力した日時"},
      {:name => 'username_input', :type => 'varchar(40)', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => "入力したユーザー名"},
      {:name => 'method_reserve', :type => 'varchar(20)', :not_null => false, :default => 'NULL', :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
      {:name => 'summary', :type => 'text', :not_null => false, :default => nil, :is_primary_key => false,
       :auto_increment => false, :set_options => nil, :comment => nil},
    ]
    assert_column_schema_of_table_schema(array_of_h_expected, actual)
    array_of_h_expected = [
      {:name => 'reserve_id', :column_names => %w(reserve_id), :is_unique => true},
      {:name => 'id_date_possibility', :column_names => %w(reservoir_id date_reserve possibility), :is_unique => true},
      {:name => 'reservoir_id', :column_names => %w(reservoir_id date_reserve possibility datetime_input), :is_unique => true},
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
        assert_equal(h_expected[:comment]       , column.comment        , "comment of COLUMN `#{name}`")
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

  ALL_TABLE_NAMES_IN_DEVELOPMENT = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)
  ALL_TABLE_NAMES_IN_PRODUCTION  = %w(base_unit field fluid reserve reserve_header reservoir unit user)
  ALL_VIEW_NAMES_IN_DEVELOPMENT  = %w(unit_with_base)
  ALL_VIEW_NAMES_IN_PRODUCTION   = %w()


  def test_get_table_names
    schezer = make_schezer_instance(*%w(-e development -g production names))

    actual_devel = nil
    actual_prod  = nil
    schezer.instance_eval do
      actual_devel = get_table_names(@conn )
      actual_prod  = get_table_names(@conn2)
    end
    expected_devel = ALL_TABLE_NAMES_IN_DEVELOPMENT
    expected_prod  = ALL_TABLE_NAMES_IN_PRODUCTION

    assert_equal(expected_devel, actual_devel, "Table names for development")
    assert_equal(expected_prod , actual_prod , "Table names for production")
  end

  def test_get_table_names_with_regexp
    schezer = make_schezer_instance(*%w(-e development names))

    do_test_get_table_names_with_regexp('div'    , %w()                                                     , schezer)
    do_test_get_table_names_with_regexp('unit'   , %w(base_unit unit)                                       , schezer)
    do_test_get_table_names_with_regexp('\Aunit' , %w(unit)                                                 , schezer)
    do_test_get_table_names_with_regexp('reserve', %w(reserve reserve_header reserve_header_trash)          , schezer)
    do_test_get_table_names_with_regexp('r'      , %w(reserve reserve_header reserve_header_trash reservoir), schezer)
    do_test_get_table_names_with_regexp('r\z'    , %w(reserve_header reservoir)                             , schezer)
  end

    def do_test_get_table_names_with_regexp(str_re, expected, schezer)
      actual = nil
      schezer.instance_eval do
        actual = get_table_names_with_regexp(@conn, str_re)
      end

      assert_equal(expected, actual, "Table names for development")
    end
    private :do_test_get_table_names_with_regexp

  def test_view_with_nil_name
    schezer = make_schezer_instance(*%w(-e development names))

    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      schezer.instance_eval do
        assert(! view?(nil, @conn))
      end
    end
  end

  def test_view_with_non_existing_name
    schezer = make_schezer_instance(*%w(-e development names))

    non_existing_view_name = "quackaboom"
    assert_raise(InfrastructureException, "InfrastructureException should have been raised") do
      schezer.instance_eval do
        assert(! view?(non_existing_view_name, @conn))
      end
    end
  end

  def test_view
    schezer = make_schezer_instance(*%w(-e development -g production names))

    assert = method(:assert)
    schezer.instance_eval do
      ALL_TABLE_NAMES_IN_DEVELOPMENT.each do |name|
        assert.call(! view?(name, @conn ))
      end
      ALL_TABLE_NAMES_IN_PRODUCTION .each do |name|
        assert.call(! view?(name, @conn2))
      end
      ALL_VIEW_NAMES_IN_DEVELOPMENT .each do |name|
        assert.call(  view?(name, @conn ))
      end
      ALL_VIEW_NAMES_IN_PRODUCTION  .each do |name|
        assert.call(  view?(name, @conn2))
      end
    end
  end

  def test_get_raw_table_schema_with_view
    schezer = make_schezer_instance(*%w(-e development -g production raw))

    assert_nil = method(:assert_nil)
    schezer.instance_eval do
      ALL_VIEW_NAMES_IN_DEVELOPMENT.each do |name|
        assert_nil.call(get_raw_table_schema(name, @conn ))
      end
      ALL_VIEW_NAMES_IN_PRODUCTION .each do |name|
        assert_nil.call(get_raw_table_schema(name, @conn2))
      end
    end
  end

  def test_get_raw_table_schema_with_table_reserve
    schezer = make_schezer_instance(*%w(-e development raw))

    table_name = 'reserve'
    actual = nil
    schezer.instance_eval do
      actual = get_raw_table_schema(table_name, @conn)
    end
    actual_lines = actual.split("\n")
    expected_lines = [
      "CREATE TABLE `reserve` (",
      "  `synthetic_id` int(10) unsigned NOT NULL auto_increment,",
      "  `reserve_id` int(10) unsigned NOT NULL,",
      "  `fluid_id` int(10) unsigned NOT NULL default '0',",
      "  `reserve` decimal(15,2) default NULL,",
      "  `unit_id` int(10) unsigned NOT NULL default '0',",
      "  PRIMARY KEY  (`synthetic_id`),",
      "  UNIQUE KEY `reserve_fluid` (`reserve_id`,`fluid_id`),",
      "  KEY `fluid_id` (`fluid_id`),",
      "  KEY `unit_id` (`unit_id`),",
      "  CONSTRAINT `reserve_ibfk_2` FOREIGN KEY (`fluid_id`) REFERENCES `fluid` (`fluid_id`) ON UPDATE CASCADE,",
      "  CONSTRAINT `reserve_ibfk_3` FOREIGN KEY (`unit_id`) REFERENCES `unit` (`unit_id`) ON UPDATE CASCADE,",
      "  CONSTRAINT `reserve_ibfk_4` FOREIGN KEY (`reserve_id`) REFERENCES `reserve_header` (`reserve_id`)" \
      +    " ON DELETE CASCADE ON UPDATE CASCADE",
      ") ENGINE=InnoDB AUTO_INCREMENT=6945 DEFAULT CHARSET=utf8"
    ]
    assert_in_lines(expected_lines, actual_lines, "Raw table schema for TABLE `#{table_name}`")
  end

  def test_get_raw_table_schema_with_table_reserve_header
    schezer = make_schezer_instance(*%w(-e development raw))

    table_name = 'reserve_header'
    actual = nil
    schezer.instance_eval do
      actual = get_raw_table_schema(table_name, @conn)
    end
    actual_lines = actual.split("\n")
    expected_lines = [
      "CREATE TABLE `reserve_header` (",
      "  `reserve_id` int(10) unsigned NOT NULL auto_increment,",
      "  `reservoir_id` int(10) unsigned NOT NULL default '0',",
      "  `date_reserve` date NOT NULL default '0000-00-00' COMMENT '鉱量の日付',",
      "  `possibility` int(10) unsigned NOT NULL default '0' COMMENT '実現確率',",
      "  `is_by_completion` tinyint(1) unsigned zerofill NOT NULL default '0'" \
      +   " COMMENT '鉱量データとして 0 であれば reserve、1 であれば reserve_by_completion を使う',",
      "  `datetime_input` datetime default NULL COMMENT '入力した日時',",
      "  `username_input` varchar(40) default NULL COMMENT '入力したユーザー名',",
      "  `method_reserve` varchar(20) default NULL,",
      "  `summary` text,",
      "  PRIMARY KEY  (`reserve_id`),",
      "  UNIQUE KEY `reserve_id` (`reserve_id`),",
      "  UNIQUE KEY `id_date_possibility` (`reservoir_id`,`date_reserve`,`possibility`),",
      "  UNIQUE KEY `reservoir_id` (`reservoir_id`,`date_reserve`,`possibility`,`datetime_input`),",
      "  CONSTRAINT `reserve_header_ibfk_1` FOREIGN KEY (`reservoir_id`) REFERENCES `reservoir` (`reservoir_id`) ON UPDATE CASCADE",
      ") ENGINE=InnoDB AUTO_INCREMENT=3710 DEFAULT CHARSET=utf8 COMMENT='埋蔵量のヘッダテーブル'"
    ]
    assert_in_lines(expected_lines, actual_lines, "Raw table schema for TABLE `#{table_name}`")
  end

  # Do not test get_create_table_result().
  # Testing get_raw_table_schema() should do.

  def test_get_row_count
    schezer = make_schezer_instance(*%w(-e development count))

    map_expected = {
      'base_unit' => 4,
      'field' => 4,
      'fluid' => 5,
      'reserve' => 4,
      'reserve_header' => 2,
      'reserve_header_trash' => 0,
      'reservoir' => 10,
      'unit' => 7,
    }

    assert_equal = method(:assert_equal)
    schezer.instance_eval do
      ALL_TABLE_NAMES_IN_DEVELOPMENT.each do |name|
        expected = map_expected[name]
        actual   = get_row_count(name, @conn)
        assert_equal.call(expected, actual, "Row count of TABLE `#{name}`")
      end
    end
  end

  def test_row_count_equal_with_table_not_exist
    schezer = make_schezer_instance(*%w(-e development -g production count))

    table_name = 'no_exist'
    assert_raise(InfrastructureException, "InfrastructureException should have been raised") do
      schezer.instance_eval do
        puts "actual = " + row_count_equal?(table_name, @conn, @conn2)
      end
    end
  end

  def test_row_count_equal_with_table_in_either_only
    schezer = make_schezer_instance(*%w(-e development -g production count))

    table_names_devel = ALL_TABLE_NAMES_IN_DEVELOPMENT
    table_names_prod  = ALL_TABLE_NAMES_IN_PRODUCTION
    table_names_either = (table_names_devel - table_names_prod) + (table_names_prod - table_names_devel)
    table_names_either.each do |table_name|
      assert_raise(InfrastructureException, "InfrastructureException should have been raised") do
        schezer.instance_eval do
          puts "actual = " + row_count_equal?(table_name, @conn, @conn2)
        end
      end
    end
  end

  def test_row_count_equal
    schezer = make_schezer_instance(*%w(-e development -g production count))

    table_names_devel = ALL_TABLE_NAMES_IN_DEVELOPMENT
    table_names_prod  = ALL_TABLE_NAMES_IN_PRODUCTION
    table_names_common = table_names_devel - (table_names_devel - table_names_prod)
    table_names_false = %w(reserve_header reserve)
    table_names_true  = table_names_common - table_names_false

    assert = method(:assert)
    schezer.instance_eval do
      table_names_true .each do |table_name|
        assert.call(  row_count_equal?(table_name, @conn, @conn2), "TABLE `#{table_name}`")
      end
      table_names_false.each do |table_name|
        assert.call(! row_count_equal?(table_name, @conn, @conn2), "TABLE `#{table_name}`")
      end
    end
  end

  def test_compare_table_names_with_no_tables
    table_names  = []
    table_names2 = []

    outs_diff_expected = []
    names_both_expected = []

    do_test_compare_table_names(table_names, table_names2, outs_diff_expected, names_both_expected)
  end

  def test_compare_table_names_with_conn_only
    table_names  = %w(base_unit field reserve_header_trash)
    table_names2 = %w(base_unit field)

    outs_diff_expected = [
      "[Tables which appears only in DB `schezer_test` (Total of 1)]:",
      "reserve_header_trash",
    ]
    names_both_expected = %w(base_unit field)

    do_test_compare_table_names(table_names, table_names2, outs_diff_expected, names_both_expected)
  end

  def test_compare_table_names_with_conn2_only
    table_names  = %w(reserve_header reserve)
    table_names2 = %w(reserve_header reserve user)

    outs_diff_expected = [
      "[Tables which appears only in DB `schezer_test2` (Total of 1)]:",
      "user",
    ]
    names_both_expected = %w(reserve_header reserve)

    do_test_compare_table_names(table_names, table_names2, outs_diff_expected, names_both_expected)
  end

  def test_compare_table_names_with_all_tables
    table_names  = ALL_TABLE_NAMES_IN_DEVELOPMENT
    table_names2 = ALL_TABLE_NAMES_IN_PRODUCTION

    outs_diff_expected = [
      "[Tables which appears only in DB `schezer_test` (Total of 1)]:",
      "reserve_header_trash",
      "[Tables which appears only in DB `schezer_test2` (Total of 1)]:",
      "user"
    ]
    names_both_expected = %w(base_unit field fluid reserve reserve_header reservoir unit)

    do_test_compare_table_names(table_names, table_names2, outs_diff_expected, names_both_expected)
  end

    def do_test_compare_table_names(table_names, table_names2, outs_diff_expected, names_both_expected)
      schezer = make_schezer_instance(*%w(-e development -g production count))

      assert_equal = method(:assert_equal)
      schezer.instance_eval do
        outs_diff_actual, names_both_actual = compare_table_names(table_names, table_names2)
        assert_equal.call( outs_diff_expected,  outs_diff_actual, "outs_diff (1st return value)")
        assert_equal.call(names_both_expected, names_both_actual, "table_names_both (2nd return value)")
      end
    end
    private :do_test_compare_table_names

  def test_to_xml_with_empty_table_names
    schezer = make_schezer_instance(*%w(-e development xml))

    assert_equal = method(:assert_equal)
    table_names = []
    expected = \
        "<?xml version='1.0' encoding='UTF-8'?>" \
      + "<table_schema/>"
    schezer.instance_eval do
      actual = to_xml(table_names).to_s
      assert_equal.call(expected, actual, "to_xml(#{table_names.inspect})")
    end
  end

  def test_to_xml
    schezer = make_schezer_instance(*%w(-e development xml))

    assert_equal = method(:assert_equal)
    table_names = %w(base_unit)
    expected_lines = [
      "  <?xml version='1.0' encoding='UTF-8'?>",
      "  <table_schema>",
      "    <table name='base_unit'>",
      "      <column name='base_unit_id' primary_key='true' not_null='true' auto_increment='true'>",
      "        <type>int(10) unsigned</type>",
      "        <default/>",
      "        <comment><![CDATA[]]></comment>",
      "      </column>",
      "      <column name='base_unit' primary_key='false' not_null='true' auto_increment='false'>",
      "        <type>varchar(40)</type>",
      "        <default/>",
      "        <comment><![CDATA[]]></comment>",
      "      </column>",
      "      <unique_key name='unique_base_unit_1' unique='true'>",
      "        <column_name>base_unit_id</column_name>",
      "      </unique_key>",
      "      <set_options/>",
      "      <table_options>",
      "        <engine>InnoDB</engine>",
      "        <default_charset>utf8</default_charset>",
      "        <collate/>",
      "        <max_rows/>",
      "        <comment><![CDATA[]]></comment>",
      "      </table_options>",
      "    </table>",
      "  </table_schema>"
    ]
    assert_in_lines = method(:assert_in_lines)
    schezer.instance_eval do
      actual = Array.new
      to_xml(table_names).write(actual, indent=1)
      actual_lines = actual.join.split("\n")
      assert_in_lines.call(expected_lines, actual_lines, "to_xml(#{table_names.inspect})")
    end
  end

  def test_initialize_xml_doc
    schezer = make_schezer_instance(*%w(-e development xml))

    assert_equal = method(:assert_equal)
    expected = \
        "<?xml version='1.0' encoding='UTF-8'?>" \
      + "<table_schema host='pluto' database='resman2'/>"
    schezer.instance_eval do
      @host     = 'pluto'
      @database = 'resman2'
      actual = initialize_xml_doc.to_s
      assert_equal.call(expected, actual, "initialize_xml_doc()")
    end
  end

  def test_configure_with_nil_name
    schezer = make_schezer_instance(*%w(-e development names))

    assert_nil = method(:assert_nil)
    filename = 'not used'
    name     = nil
    schezer.instance_eval do
      assert_nil.call(configure(filename, name), "configure() with nil name")
    end
  end

  def test_configure_with_nil_filename
    schezer = make_schezer_instance(*%w(-e development names))

    filename = nil
    name     = 'development'
    msg = "ExitWithMessageException should have been raised"
    assert_raise(ExitWithMessageException, msg) do
      schezer.instance_eval do
        configure(filename, name)
      end
    end
  end

  def test_configure_with_non_exisiting_filename
    schezer = make_schezer_instance(*%w(-e development names))

    filename = 'non_existing_filename'
    name     = 'development'
    msg = "ExitWithMessageException should have been raised"
    assert_raise(ExitWithMessageException, msg) do
      schezer.instance_eval do
        configure(filename, name)
      end
    end
  end

  def test_configure
    schezer = make_schezer_instance(*%w(-e development names))

    assert_not_nil = method(:assert_not_nil)
    assert_equal   = method(:assert_equal)
    filename = 'unit_test/schema_browser/db/schezer_test.yml'
    name     = 'development'
    schezer.instance_eval do
      conn = configure(filename, name)
      assert_not_nil.call(conn, "DBConnection")
      assert_equal.call('localhost'   , conn.host       , "host")
      assert_equal.call('schezer_test', conn.username   , "username")
      assert_equal.call('schezer_test', conn.database   , "database")
      assert_equal.call('utf8'        , conn.encoding   , "encoding")
      assert_equal.call('development' , conn.environment, "environment")
    end
  end

  # ===== Test class Schezer::DBConnection =====

    def make_dbconnection_instance(schezer)
      schezer.instance_eval do
        return @conn.dup
      end
    end
    private :make_dbconnection_instance

  def test_configuration_suffices_of_class_dbconnection
    schezer = make_schezer_instance(*%w(-e development names))

    dbconn = make_dbconnection_instance(schezer)
    assert(dbconn.kind_of?(Schezer::DBConnection), "class Schezer::DBConnection?")
    assert(dbconn.configuration_suffices?, "configuration_suffices?")
    dbconn.instance_eval do
      @host = ''
    end
    assert(! dbconn.configuration_suffices?, "configuration_suffices?")

    dbconn = make_dbconnection_instance(schezer)
    dbconn.instance_eval do
      @username = ''
    end
    assert(! dbconn.configuration_suffices?, "configuration_suffices?")

    dbconn = make_dbconnection_instance(schezer)
    dbconn.instance_eval do
      @database = ''
    end
    assert(! dbconn.configuration_suffices?, "configuration_suffices?")
  end

  def test_get_query_result_of_class_dbconnection
    schezer = make_schezer_instance(*%w(-e development names))
    dbconn = make_dbconnection_instance(schezer)

    sqls_wrong = [
      "SHOW DATABASE",
      "SHOW TABLE",
      "SELECT * FROM",
    ]
    sqls_wrong.each do |sql|
      assert_raise(Mysql::Error, "SQL \"#{sql}\"") do
        dbconn.get_query_result(sql)
      end
    end

    sqls_right = [
      "SHOW DATABASES",
      "SHOW TABLES",
      "SELECT * FROM reserve",
    ]
    sqls_right.each do |sql|
      assert_not_nil(dbconn.get_query_result(sql), "SQL \"#{sql}\"")
    end
  end

  # ===== Test class ForeignKey =====

  def test_initialize_of_class_foreign_key
    name            = 'name'
    column_name     = 'colname'
    ref_table_name  = 'reftablename'
    ref_column_name = 'refcolumnname'
    on_delete       = 'ondelete'
    on_update       = 'onupdate'

    fk = ForeignKey.new(name, column_name, ref_table_name, ref_column_name, on_delete, on_update)
    assert_equal(name           , fk.name           , "name")
    assert_equal(column_name    , fk.column_name    , "column_name")
    assert_equal(ref_table_name , fk.ref_table_name , "ref_table_name")
    assert_equal(ref_column_name, fk.ref_column_name, "ref_column_name")
    assert_equal(on_delete      , fk.on_delete      , "on_delete")
    assert_equal(on_update      , fk.on_update      , "on_update")
  end

  def test_to_xml_of_class_foreign_key
    name            = 'name'
    column_name     = 'colname'
    ref_table_name  = 'reftablename'
    ref_column_name = 'refcolumnname'
    on_delete       = 'ondelete'
    on_update       = 'onupdate'

    fk = ForeignKey.new(name, column_name, ref_table_name, ref_column_name, on_delete, on_update)

    expected = 
        "<foreign_key name='name'>" \
      +   "<column_name>colname</column_name>" \
      +   "<reference_table_name>reftablename</reference_table_name>" \
      +   "<reference_column_name>refcolumnname</reference_column_name>" \
      +   "<on_delete>ondelete</on_delete>" \
      +   "<on_update>onupdate</on_update>" \
      + "</foreign_key>"
    assert_equal(expected, fk.to_xml.to_s, "ForeignKey#to_xml")
  end

  def test_parse_of_class_foreign_key
    input = "  CONSTRAINT `reserve_ibfk_4` FOREIGN KEY (`reserve_id`)" \
          + " REFERENCES `reserve_header` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE  "
    fk = ForeignKey.parse(input)
    
    assert_not_nil(fk, "ForeignKey instance")
    assert_equal('reserve_ibfk_4', fk.name           , "name")
    assert_equal('reserve_id'    , fk.column_name    , "column_name")
    assert_equal('reserve_header', fk.ref_table_name , "ref_table_name")
    assert_equal('id'            , fk.ref_column_name, "ref_column_name")
    assert_equal('RESTRICT'      , fk.on_delete      , "on_delete")
    assert_equal('CASCADE'       , fk.on_update      , "on_update")
  end

  # ===== Test class Key =====

  def test_initialize_of_class_key
    name         = 'name'
    column_names = %w(colA colB colC)
    is_unique    = true

    key = Key.new(name, column_names, is_unique)
    assert_equal(name        , key.name        , "names")
    assert_equal(column_names, key.column_names, "column_names")
    assert_equal(is_unique   , key.unique?     , "is_unique")
  end

  def test_unique_of_class_key
    [true, false].each do |is_unique|
      key = Key.new('', [], is_unique)
      assert_equal(is_unique, key.unique?, "Key#unique? of #{is_unique}")
    end
  end

  def test_key_name_of_class_key
    [
      [true , 'unique_key'],
      [false, 'key'],
    ].each do |is_unique, expected|
      key = Key.new('', [], is_unique)
      assert_equal(expected, key.key_name, "Key#key_name for unique? of #{is_unique}")
    end
  end

  def test_to_xml_of_class_key
    name         = 'name'
    column_names = %w(colA colB colC)

    format_expected =
        "<%1$s name='name' unique='%2$s'>" \
      +   "<column_name>colA</column_name>" \
      +   "<column_name>colB</column_name>" \
      +   "<column_name>colC</column_name>" \
      + "</%1$s>"

    [true, false].each do |is_unique|
      key = Key.new(name, column_names, is_unique)
      expected = sprintf(format_expected, key.key_name, key.unique?)
      assert_equal(expected, key.to_xml.to_s, "Key#to_xml for unique? of #{is_unique}")
    end
  end

  def test_parse_of_class_key
    [
      ["  KEY `name1` (`col1`)"                     , 'name1', %w(col1)          , false],
      ["  KEY `name2` (`col1`,`col2`)"              , 'name2', %w(col1 col2)     , false],
      ["  UNIQUE KEY `name3` (`col1`)"              , 'name3', %w(col1)          , true ],
      ["  UNIQUE KEY `name4` (`col1`,`col2`,`col3`)", 'name4', %w(col1 col2 col3), true ],
    ].each do |input, name, column_names, is_unique|
      key = Key.parse(input)
      assert_equal(name        , key.name        , "names")
      assert_equal(column_names, key.column_names, "column_names")
      assert_equal(is_unique   , key.unique?     , "is_unique")
    end
  end

  # ===== Test class ColumnSchema =====

  def test_initialize_of_class_column_schema_not_nil
    column_schema = make_empty_column_schema
    assert_not_nil(column_schema, "ColumnSchema.new")
  end

    def make_empty_column_schema(name='name', type='type', auto_increment=false)
      column_schema = ColumnSchema.new(name, nil, nil, false)
      column_schema.instance_eval do
        @type = type
        @auto_increment = auto_increment
      end
      return column_schema
    end
    private :make_empty_column_schema

  def test_not_null_of_class_column_schema
    column_schema = make_empty_column_schema

    [true, false].each do |not_null|
      column_schema.instance_eval do
        @not_null = not_null
      end
      assert_equal(not_null, column_schema.not_null?, "ColumnSchema#not_null?")
    end
  end

  def test_auto_increment_of_class_column_schema
    column_schema = make_empty_column_schema

    [true, false].each do |auto_increment|
      column_schema.instance_eval do
        @auto_increment = auto_increment
      end
      assert_equal(auto_increment, column_schema.auto_increment?, "ColumnSchema#auto_increment?")
    end
  end

  def test_primary_key_of_class_column_schema
    column_schema = make_empty_column_schema

    [true, false].each do |is_primary_key|
      column_schema.instance_eval do
        @is_primary_key = is_primary_key
      end
      assert_equal(is_primary_key, column_schema.primary_key?, "ColumnSchema#primary_key?")
    end
  end

  def test_is_primary_key_assign_of_class_column_schema
    column_schema = make_empty_column_schema

    [true, false].each do |is_primary_key|
      column_schema.is_primary_key = is_primary_key
      assert_equal(is_primary_key, column_schema.primary_key?, "ColumnSchema#primary_key?")
    end
  end

  def test_comment_blank_of_class_column_schema
    column_schema = make_empty_column_schema

    [
      [nil        , true ],
      [""         , true ],
      ["a"        , false],
      ["A comment", false],
    ].each do |comment, expected|
      column_schema.instance_eval do
        @comment = comment
      end
      assert_equal(expected, column_schema.comment_blank?, "ColumnSchema#comment_blank?")
    end
  end

  def test_hard_to_sort_of_class_column_schema
    column_schema = make_empty_column_schema

    [
      ['BLOB'         , true ],
      ['MEDIUMBLOB'   , true ],
      ['LONGBLOB'     , true ],
      ['blob'         , true ],
      ['mediumblob'   , true ],
      ['longblob'     , true ],
      ['BLOB(1)'      , true ],
      ['MEDIUMBLOB(1)', true ],
      ['LONGBLOB(1)'  , true ],
      ['BLO'          , false],
      ['MEDIUMBLO'    , false],
      ['LONGBLO'      , false],
      ['TEXT'         , false],
      ['MEDIUMTEXT'   , false],
      ['LONGTEXT'     , false],
    ].each do |type, expected|
      column_schema.instance_eval do
        @type = type
      end
      assert_equal(expected, column_schema.hard_to_sort?, "ColumnSchema#hard_to_sort?")
    end
  end

  def test_too_long_to_display_of_class_column_schema
    column_schema = make_empty_column_schema

    [
      ['TEXT'         , true ],
      ['MEDIUMTEXT'   , true ],
      ['LONGTEXT'     , true ],
      ['text'         , true ],
      ['mediumtext'   , true ],
      ['longtext'     , true ],
      ['TEXT(1)'      , true ],
      ['MEDIUMTEXT(1)', true ],
      ['LONGTEXT(1)'  , true ],
      ['TEX'          , false],
      ['MEDIUMTEX'    , false],
      ['LONGTEX'      , false],
      ['BLOB'         , false],
      ['MEDIUMBLOB'   , false],
      ['LONGBLOB'     , false],
    ].each do |type, expected|
      column_schema.instance_eval do
        @type = type
      end
      assert_equal(expected, column_schema.too_long_to_display?, "ColumnSchema#too_long_to_display?")
    end
  end

  def test_numerical_type_of_class_column_schema
    column_schema = make_empty_column_schema

    types_true  = %w!NUMERIC DECIMAL INTEGER SMALLINT TINYINT FLOAT REAL DOUBLE INT DEC
                     numeric decimal integer smallint tinyint float real double int dec
                     NUMERIC(1) DECIMAL(1) INTEGER(1) SMALLINT(1) TINYINT(1) FLOAT(1) REAL(1) DOUBLE(1) INT(1) DEC(1)!
    types_false = %w!CHAR VARCHAR DATE TIME DATETIME BLOB MEDIUMBLOB LONGBLOB TEXT MEDIUMTEXT LONGTEXT
                     CHAR(1) VARCHAR(1) DATE(1) TIME(1) DATETIME(1) BLOB(1) MEDIUMBLOB(1) LONGBLOB(1)
                     TEXT(1) MEDIUMTEXT(1) LONGTEXT(1)!

    [
      [types_true , true ],
      [types_false, false],
    ].each do |types, expected|
      types.each do |type|
        column_schema.instance_eval do
          @type = type
        end
        assert_equal(expected, column_schema.numerical_type?, "ColumnSchema#numerical_type?")
      end
    end
  end

  def test_equals_of_class_column_schema
    column_schema1 = make_empty_column_schema
    column_schema2 = make_empty_column_schema

    [
      ['name1', 'type1', 'name1', 'type1', true ],
      ['name1', 'type1', 'name2', 'type1', false],
      ['name1', 'type1', 'name1', 'type2', false],
      ['name1', 'type1', 'name2', 'type2', false],
    ].each do |name1, type1, name2, type2, expected|
      column_schema1.instance_eval do
        @name = name1
        @type = type1
      end
      column_schema2.instance_eval do
        @name = name2
        @type = type2
      end
      assert_equal(expected, column_schema1 == column_schema2)
    end
  end

  def test_to_xml_of_class_column_schema
    column_schema = make_empty_column_schema

    expected = 
        "<column name='id' primary_key='true' not_null='true' auto_increment='true'>" \
      +   "<type>int(10) unsigned</type>" \
      +   "<default/>" \
      +   "<comment><![CDATA[Unique ID generated by the database]]></comment>" \
      + "</column>"

    column_schema.instance_eval do
      @name = 'id'
      @is_primary_key = true
      @not_null       = true
      @auto_increment = true
      @type = 'int(10) unsigned'
      @defualt = nil
      @comment = "Unique ID generated by the database"
    end
    assert_equal(expected, column_schema.to_xml.to_s, "ColumnSchema#to_xml()")
  end

  def test_parse_definition_of_class_column_schema
    assert_equal = method(:assert_equal)
    [                                            # type                not_null default       auto_i set_options
      ["int(10) unsigned NOT NULL auto_increment", 'int(10) unsigned', true   , nil         , true , nil],
      ["int(10) unsigned NOT NULL default '0'"   , 'int(10) unsigned', true   , '0'         , false, nil],
      ["date default '0000-00-00'"               , 'date'            , false  , '0000-00-00', false, nil],
      ["set('one','two','etc') default NULL"     , 'set'             , false  , nil         , false, "('one','two','etc')"],
    ].each do |definition, type, not_null, default, auto_increment, set_options|
      column_schema = make_empty_column_schema
      column_schema.instance_eval do
        parse_definition(definition, capitalizes_types=false)
        assert_equal.call(type          , @type          , "@type")
        assert_equal.call(not_null      , @not_null      , "@not_null")
        assert_equal.call(auto_increment, @auto_increment, "@auto_increment")
        assert_equal.call(set_options   , @set_options   , "@set_options")
      end

      column_schema = make_empty_column_schema
      column_schema.instance_eval do
        parse_definition(definition, capitalizes_types=true)
        assert_equal.call(type.upcase   , @type          , "@type")
        assert_equal.call(not_null      , @not_null      , "@not_null")
        assert_equal.call(auto_increment, @auto_increment, "@auto_increment")
        assert_equal.call(set_options   , @set_options   , "@set_options")
      end
    end
  end

  def test_get_type_of_class_column_schema
    column_schema = make_empty_column_schema

    assert_equal = method(:assert_equal)
    [
      [[]                       , ""],
      [%w(int)                  , "int"],
      [%w(int unsigned)         , "int unsigned"],
      [%w(int unsign)           , "int"],
      [%w(int unsigned zerofill), "int unsigned zerofill"],
      [%w(int unsigned zerofil) , "int unsigned"],
      [%w(char)                 , "char"],
      [%w(char unicode)         , "char unicode"],
      [%w(char utf8_unicode_ci) , "char utf8_unicode_ci"],
    ].each do |terms, expected|
      column_schema.instance_eval do
        [false, true].each do |capitalizes_types|
          msg = "get_type(#{terms.inspect}, #{capitalizes_types})"
          expected.upcase! if capitalizes_types
          actual = get_type(terms.dup, capitalizes_types)
          assert_equal.call(expected, actual, msg)
        end
      end
    end
  end

  def test_get_null_default_and_auto_increment_of_class_column_schema_raise_exception
    column_schema = make_empty_column_schema

    msg = "UnsupportedColumnDefinitionException should have been raised"
    [
      %w(type),
      %w(null not),
      %w(not null auto),
    ].each do |terms|
      assert_raise(UnsupportedColumnDefinitionException, msg) do
        column_schema.instance_eval do
          get_null_default_and_auto_increment(terms)
        end
      end
    end
  end

  def test_get_null_default_and_auto_increment_of_class_column_schema
    column_schema = make_empty_column_schema

    assert_equal = method(:assert_equal)
    [
      [[]                , [false, nil   , false]],
      [%w(null)          , [false, nil   , false]],
      [%w(not null)      , [true , nil   , false]],
      [%w(default '')    , [false, "''"  , false]],
      [%w(default '0')   , [false, '0'   , false]],
      [%w(default '00-0'), [false, '00-0', false]],
      [%w(auto_increment), [false, nil   , true ]],
      [%w(null     default '0')   , [false, '0', false]],
      [%w(not null default '0')   , [true , '0', false]],
      [%w(null     auto_increment), [false, nil, true ]],
      [%w(not null auto_increment), [true , nil, true ]],
      [%w(null     default '0' auto_increment), [false, '0', true]],
      [%w(not null default '0' auto_increment), [true , '0', true]],
    ].each do |terms, expected|
      column_schema.instance_eval do
        msg = "get_null_default_and_auto_increment(#{terms.inspect})"
        actual = get_null_default_and_auto_increment(terms.dup)
        assert_equal.call(expected, actual, msg)

        terms = terms.map { |term| term.upcase }
        msg = "get_null_default_and_auto_increment(#{terms.inspect})"
        actual = get_null_default_and_auto_increment(terms.dup)
        assert_equal.call(expected, actual, msg)
      end
    end
  end

  def test_parse_of_class_column_schema_returns_nil
    [
      "",
      "id int(4)",
    ].each do |line|
      assert_nil(ColumnSchema.parse(line, true ), "ColumnSchema.parse(\"#{line}\", true)")
      assert_nil(ColumnSchema.parse(line, false), "ColumnSchema.parse(\"#{line}\", false)")
    end
  end

  def test_parse_of_class_column_schema
    [
      ["`id` int(10) unsigned NOT NULL auto_increment COMMENT '自動生成されたID'",
          'id', 'int(10) unsigned', true, nil, true, "自動生成されたID", nil],
      [" `date_reserve` date default '0000-00-00'",
          'date_reserve', 'date', false, '0000-00-00', false, nil, nil],
      ["`method_reserve` set('volumetic','decline','simulation') default NULL COMMENT '評価方法'",
          'method_reserve', 'set', false, 'NULL', false, "評価方法", "('volumetic','decline','simulation')"],
    ].each do |line, name, type, not_null, default, auto_inc, comment, set_options|
      column_schema = ColumnSchema.parse(line, true)
      assert_equal(name       , column_schema.name           , "name")
      assert_equal(type.upcase, column_schema.type           , "type")
      assert_equal(not_null   , column_schema.not_null?      , "not_null?")
      assert_equal(default    , column_schema.default        , "default")
      assert_equal(auto_inc   , column_schema.auto_increment?, "auto_increment?")
      assert_equal(comment    , column_schema.comment        , "comment")
      assert_equal(set_options, column_schema.set_options    , "set_options")

      column_schema = ColumnSchema.parse(line, false)
      assert_equal(name       , column_schema.name           , "name")
      assert_equal(type       , column_schema.type           , "type")
      assert_equal(not_null   , column_schema.not_null?      , "not_null?")
      assert_equal(default    , column_schema.default        , "default")
      assert_equal(auto_inc   , column_schema.auto_increment?, "auto_increment?")
      assert_equal(comment    , column_schema.comment        , "comment")
      assert_equal(set_options, column_schema.set_options    , "set_options")
    end
  end

  # ===== Test class TableSchema =====

  def test_initialize_of_class_table_schema_raises_exception
    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      TableSchema.new(nil, 80)
    end
    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      TableSchema.new("", nil)
    end
  end

  def test_initialize_of_class_table_schema
    table_schema = TableSchema.new("", 80)
    assert_not_nil(table_schema, "TableSchema.new")
  end

  #TODO: Test parse_raw_schema()?

  def test_column_names_of_class_table_schema
    table_schema = make_empty_table_schema

    make_column_schema_mock = method(:make_column_schema_mock)
    table_schema.instance_eval do
      @columns = Array.new
      @columns << make_column_schema_mock.call('id'  , true )
      @columns << make_column_schema_mock.call('name', false)
      @columns << make_column_schema_mock.call('addr', false)
      @columns << make_column_schema_mock.call('pid' , true )
    end
    assert_equal(%w(id name addr pid), table_schema.column_names, "TableSchema#column_names")
  end

    def make_empty_table_schema(table_name=nil)
      table_schema = TableSchema.new("", 0)
      table_schema.instance_eval do
        @name = table_name
      end
      return table_schema
    end
    private :make_empty_table_schema

    def set_columns_to_table_schema(table_schema, *columns)
      table_schema.instance_eval do
        @columns = columns
      end
    end
    private :set_columns_to_table_schema

  def test_columns_with_primary_key_of_class_table_schema
    table_schema = make_empty_table_schema

    column_id   = make_empty_column_schema('id'  , 'int' )
    column_name = make_empty_column_schema('name', 'char')
    column_addr = make_empty_column_schema('addr', 'char')
    column_pid  = make_empty_column_schema('pid' , 'int' )
    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_pid)

    table_schema.instance_eval do
      @primary_keys = %w(id)
    end
    assert_equal([column_id], table_schema.columns_with_primary_key, "TableSchema#columns_with_primary_key")

    table_schema.instance_eval do
      @primary_keys = %w(id pid)
    end
    assert_equal([column_id, column_pid], table_schema.columns_with_primary_key, "TableSchema#columns_with_primary_key")
  end

  def test_has_columns_hard_to_sort_of_class_table_schema
    table_schema = make_empty_table_schema

    assert(! table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")

    column_id    = make_empty_column_schema('id'   , 'int' )
    column_name  = make_empty_column_schema('name' , 'char')
    column_addr  = make_empty_column_schema('addr' , 'char')
    column_pid   = make_empty_column_schema('pid'  , 'int' )
    column_blob  = make_empty_column_schema('blob' , 'blob')
    column_mblob = make_empty_column_schema('mblob', 'mediumblob')
    column_lblob = make_empty_column_schema('lblob', 'longblob')

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_pid)
    assert(! table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob, column_pid)
    assert(  table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_mblob, column_addr, column_pid)
    assert(  table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")

    set_columns_to_table_schema(table_schema, column_lblob, column_id, column_name, column_addr, column_pid)
    assert(  table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_mblob, column_lblob, column_addr, column_pid)
    assert(  table_schema.has_columns_hard_to_sort?, "TableSchema#hard_to_sort?")
  end

  def test_column_names_to_sort_of_class_table_schema
    table_schema = make_empty_table_schema

    assert_equal([], table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    column_id    = make_empty_column_schema('id'   , 'int' , auto_increment=true)
    column_name  = make_empty_column_schema('name' , 'char')
    column_addr  = make_empty_column_schema('addr' , 'char')
    column_pid   = make_empty_column_schema('pid'  , 'int' )
    column_blob  = make_empty_column_schema('blob' , 'blob')
    column_mblob = make_empty_column_schema('mblob', 'mediumblob')
    column_lblob = make_empty_column_schema('lblob', 'longblob')

    set_columns_to_table_schema(table_schema           , column_name)
    assert_equal(%w(name)         , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name)
    assert_equal(%w(name)         , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr)
    assert_equal(%w(name addr)    , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_pid)
    assert_equal(%w(name addr pid), table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob)
    assert_equal(%w(name addr)    , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob, column_mblob)
    assert_equal(%w(name addr)    , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob, column_mblob, column_lblob)
    assert_equal(%w(name addr)    , table_schema.column_names_to_sort, "TableSchema#column_names_to_sort")

    # Now test with argument includes_auto_increment of true

    set_columns_to_table_schema(table_schema           , column_name)
    assert_equal(%w(name)            , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name)
    assert_equal(%w(id name)         , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr)
    assert_equal(%w(id name addr)    , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_pid)
    assert_equal(%w(id name addr pid), table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob)
    assert_equal(%w(id name addr)    , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob, column_mblob)
    assert_equal(%w(id name addr)    , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")

    set_columns_to_table_schema(table_schema, column_id, column_name, column_addr, column_blob, column_mblob, column_lblob)
    assert_equal(%w(id name addr)    , table_schema.column_names_to_sort(true), "TableSchema#column_names_to_sort")
  end

  def test_difference_of_class_table_schema_raises_exception
    table_schema = make_empty_table_schema

    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      table_schema.difference(nil)
    end
    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      table_schema.difference(Object.new)
    end
    assert_raise(ArgumentError, "ArgumentError should have been raised") do
      table_schema.difference(make_empty_column_schema)
    end
  end

  def test_difference_of_class_table_schema
    table_schema1 = make_empty_table_schema('table1')
    table_schema2 = make_empty_table_schema('table2')

    diff = table_schema1.difference(table_schema2)
    assert(diff.kind_of?(TableSchemaDifference), "Class of return value of TableSchema#difference()")

    assert_equal = method(:assert_equal)
    diff.instance_eval do
      assert_equal.call('table1', @schema1.name, "Table name of @schema1 of the TableSchemaDifference")
      assert_equal.call('table2', @schema2.name, "Table name of @schema2 of the TableSchemaDifference")
    end
  end

  def test_equals_of_class_table_schema
    table_schema1 = make_empty_table_schema('table1')
    table_schema2 = make_empty_table_schema('table2')

    column_id    = make_empty_column_schema('id'   , 'int' , auto_increment=true)
    column_name  = make_empty_column_schema('name' , 'char')
    column_addr  = make_empty_column_schema('addr' , 'char')
    column_pid   = make_empty_column_schema('pid'  , 'int' )

    [
      [[]                                               , []],
      [[column_id]                                      , [column_id]],
      [[column_id, column_name]                         , [column_id, column_name]],
      [[column_id, column_name, column_addr, column_pid], [column_id, column_name, column_addr, column_pid]],
    ].each do |columns1, columns2|
      set_columns_to_table_schema(table_schema1, *columns1)
      set_columns_to_table_schema(table_schema2, *columns2)
      assert(table_schema1 == table_schema2, "== should be true if both columns equals")
    end

    [
      [[]                                   , [column_id]],
      [[column_id]                          , [column_id, column_name]],
      [[column_name, column_id]             , [column_id, column_name]],
      [[column_id, column_name, column_addr], [column_id, column_name, column_addr, column_pid]],
    ].each do |columns1, columns2|
      set_columns_to_table_schema(table_schema1, *columns1)
      set_columns_to_table_schema(table_schema2, *columns2)
      assert(table_schema1 != table_schema2, "== should be false if both columns different")
    end
  end

  def test_to_s_of_class_table_schema
    raw_schema = \
      "CREATE TABLE `base_unit` (
        `base_unit_id` int(10) unsigned NOT NULL auto_increment,
        `base_unit` varchar(40) NOT NULL,
        PRIMARY KEY  (`base_unit_id`),
        UNIQUE KEY `unique_base_unit_1` (`base_unit_id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8"
    expected_lines = [
      "TABLE `base_unit`: Comment \"(n/a)\"",
      "+--------------+------------------+------+-----+---------+-----------+",
      "| Field        | Type             | Null | Key | Default | Extra     |",
      "+--------------+------------------+------+-----+---------+-----------+",
      "| base_unit_id | int(10) unsigned | NO   | PRI |         | auto inc. |",
      "| base_unit    | varchar(40)      | NO   |     |         |           |",
      "+--------------+------------------+------+-----+---------+-----------+",
      "primary key = `base_unit_id`",
      "unique_key `unique_base_unit_1` (`base_unit_id`)",
      "engine=InnoDB",
      "default_charset=utf8",
      "collate=(n/a)",
      "max_rows=(n/a)"
    ]
    do_test_to_s_of_class_table_schema(expected_lines, raw_schema)

    raw_schema = \
      "CREATE TABLE `reserve_header` (
        `reserve_id` int(10) unsigned NOT NULL auto_increment,
        `reservoir_id` int(10) unsigned NOT NULL default '0',
        `date_reserve` date NOT NULL default '0000-00-00' COMMENT '鉱量の日付',
        `possibility` int(10) unsigned NOT NULL default '0' COMMENT '実現確率',
        `is_by_completion` tinyint(1) unsigned zerofill NOT NULL default '0' COMMENT '鉱量データとして 0 であれば reserve、1 であれば reserve_by_completion を使う',
        `datetime_input` datetime default NULL COMMENT '入力した日時',
        `username_input` varchar(40) default NULL COMMENT '入力したユーザー名',
        `method_reserve` varchar(20) default NULL,
        `summary` text,
        PRIMARY KEY  (`reserve_id`),
        UNIQUE KEY `reserve_id` (`reserve_id`),
        UNIQUE KEY `id_date_possibility` (`reservoir_id`,`date_reserve`,`possibility`),
        UNIQUE KEY `reservoir_id` (`reservoir_id`,`date_reserve`,`possibility`,`datetime_input`),
          CONSTRAINT `reserve_header_ibfk_1` FOREIGN KEY (`reservoir_id`) REFERENCES `reservoir` (`reservoir_id`) ON UPDATE CASCADE
      ) ENGINE=InnoDB AUTO_INCREMENT=3710 DEFAULT CHARSET=utf8 COMMENT='埋蔵量のヘッダテーブル'"
    expected_lines = [
      "TABLE `reserve_header`: Comment \"埋蔵量のヘッダテーブル\"",
      "+------------------+------------------------------+------+-----+------------+-----------+",
      "| Field            | Type                         | Null | Key | Default    | Extra     |",
      "+------------------+------------------------------+------+-----+------------+-----------+",
      "| reserve_id       | int(10) unsigned             | NO   | PRI |            | auto inc. |",
      "| reservoir_id     | int(10) unsigned             | NO   |     | 0          |           |",
      "| date_reserve     | date                         | NO   |     | 0000-00-00 |           |",
      "| possibility      | int(10) unsigned             | NO   |     | 0          |           |",
      "| is_by_completion | tinyint(1) unsigned zerofill | NO   |     | 0          |           |",
      "| datetime_input   | datetime                     |      |     | NULL       |           |",
      "| username_input   | varchar(40)                  |      |     | NULL       |           |",
      "| method_reserve   | varchar(20)                  |      |     | NULL       |           |",
      "| summary          | text                         |      |     |            |           |",
      "+------------------+------------------------------+------+-----+------------+-----------+",
      "+------------------+------------------------------------------------------------------------------+",
      "| Field            | Comment                                                                      |",
      "+------------------+------------------------------------------------------------------------------+",
      "| reserve_id       | RDBMSが生成する一意のID番号                                                  |",
      "| reservoir_id     |                                                                              |",
      "| date_reserve     | 鉱量の日付                                                                   |",
      "| possibility      | 実現確率                                                                     |",
      "| is_by_completion | 鉱量データとして 0 であれば reserve、1 であれば reserve_by_completion を使う |",
      "| datetime_input   | 入力した日時                                                                 |",
      "| username_input   | 入力したユーザー名                                                           |",
      "| method_reserve   |                                                                              |",
      "| summary          |                                                                              |",
      "+------------------+------------------------------------------------------------------------------+",
      "primary key = `reserve_id`",
      "unique_key `reserve_id` (`reserve_id`)",
      "unique_key `id_date_possibility` (`reservoir_id`,`date_reserve`,`possibility`)",
      "unique_key `reservoir_id` (`reservoir_id`,`date_reserve`,`possibility`,`datetime_input`)",
      "foreign key `reserve_header_ibfk_1` (`reservoir_id`) refs `reservoir` (`reservoir_id`)",
      "    on update CASCADE on delete RESTRICT",
      "engine=InnoDB",
      "default_charset=utf8",
      "collate=(n/a)",
      "max_rows=(n/a)"
    ]
    do_test_to_s_of_class_table_schema(expected_lines, raw_schema)
  end

    TERMINAL_WIDTH = 80

    def do_test_to_s_of_class_table_schema(expected_lines, raw_schema)
      table_schema = TableSchema.new(raw_schema, TERMINAL_WIDTH)
      actual_lines = table_schema.to_s.split("\n")
      assert_in_lines(expected_lines, actual_lines, "TableSchema#to_s with TABLE `#{table_schema.name}`")
    end

  def test_to_xml_of_class_table_schema
    table_schema = make_table_schema_for_test_to_xml
    actual = Array.new
    table_schema.to_xml.write(actual, 1)
    actual_lines = actual.join.split("\n")

    assert_in_lines(EXPECTED_LINES_FOR_TEST_TO_XML, actual_lines, "TableSchema#to_xml")
  end

    EXPECTED_LINES_FOR_TEST_TO_XML = [
      "<table name='table1'>",
      "    <col name='col0'/>",
      "    <col name='col1'/>",
      "    <col name='col2'/>",
      "    <unq name='unq0'/>",
      "    <unq name='unq1'/>",
      "    <frg name='frg0'/>",
      "    <frg name='frg1'/>",
      "    <key name='key0'/>",
      "    <key name='key1'/>",
      "    <set_options/>",
      "    <table_options>",
      "      <engine>oracle</engine>",
      "      <default_charset>euc-jp</default_charset>",
      "      <collate>jaJp</collate>",
      "      <max_rows>876</max_rows>",
      "      <comment><![CDATA[Virtual schema for tests]]></comment>",
      "    </table_options>",
      "  </table>"
    ]

    def make_table_schema_for_test_to_xml
      def make_element_mock(type, name)
        mock = Object.new
        mock.instance_variable_set(:@type, type)
        mock.instance_variable_set(:@name, name)
        def mock.to_xml
          xml = REXML::Element.new(@type)
          xml.add_attribute('name', @name)
          xml
        end
        def mock.set_options
          nil
        end
        return mock
      end
      def make_array_of_element_mocks(type, num_elements)
        mocks = Array.new
        num_elements.times do |i|
          mocks << make_element_mock(type, type + i.to_s)
        end
        mocks
      end
      make_array_of_element_mocks = method(:make_array_of_element_mocks)

      table_schema = make_empty_table_schema('table1')
      table_schema.instance_eval do
        @columns      = make_array_of_element_mocks.call('col', 3)
        @unique_keys  = make_array_of_element_mocks.call('unq', 2)
        @foreign_keys = make_array_of_element_mocks.call('frg', 2)
        @keys         = make_array_of_element_mocks.call('key', 2)
        @engine          = 'oracle'
        @default_charset = 'euc-jp'
        @collate         = 'jaJp'
        @max_rows        = '876'
        @comment         = 'Virtual schema for tests'
      end

      return table_schema
    end
    private :make_table_schema_for_test_to_xml

  def test_all_columns_comments_blank_of_class_table_schema
    do_test_all_columns_comments_blank_of_class_table_schema([false]            , false)
    do_test_all_columns_comments_blank_of_class_table_schema([true, false]      , false)
    do_test_all_columns_comments_blank_of_class_table_schema([true, true, false], false)
    do_test_all_columns_comments_blank_of_class_table_schema([true]             , true)
    do_test_all_columns_comments_blank_of_class_table_schema([true, true]       , true)
    do_test_all_columns_comments_blank_of_class_table_schema([true, true, true] , true)
  end

    def do_test_all_columns_comments_blank_of_class_table_schema(bools, expected)
      assert_equal = method(:assert_equal)

      table_schema = make_empty_table_schema
      table_schema.instance_eval do
        @columns = Array.new
        bools.map do |bool|
          column_mock = Object.new
          column_mock.instance_variable_set(:@is_comment_blank, bool)
          def column_mock.comment_blank?
            @is_comment_blank
          end
          @columns << column_mock
        end

        assert_equal.call(expected, all_columns_comments_blank?, "TableSchema#all_columns_comments_blank?")
      end
    end
    private :do_test_all_columns_comments_blank_of_class_table_schema

  def test_to_map_table_items_of_class_table_schema
    name = 'columnA'
    column_schema = make_empty_column_schema(name, type='int', auto_increment=true)

    column_schema.instance_eval do
      @not_null = true
      @default = '9999'
      @comment = "virutal column 'columnA'"
    end

    table_schema = make_empty_table_schema
    map_items = nil
    table_schema.instance_eval do
      @primary_keys = [name]
      f_key = Object.new
      f_key.instance_variable_set(:@name, name)
      def f_key.name; @name; end
      @foreign_keys = [f_key]
      map_items = to_map_table_items(column_schema)
    end

    expected_not_null = TableSchema::ITEMS_NOT_NULL
    expected_auto_inc = TableSchema::ITEMS_AUTO_INCREMENT
    assert_equal(name                      , map_items[TableSchema::INDEX_NAME]   , "TableSchema#to_map_table_items[:name]")
    assert_equal(type                      , map_items[TableSchema::INDEX_TYPE]   , "TableSchema#to_map_table_items[:type]")
    assert_equal(expected_not_null         , map_items[TableSchema::INDEX_NULL]   , "TableSchema#to_map_table_items[:null]")
    assert_equal("PRI,FK"                  , map_items[TableSchema::INDEX_KEYS]   , "TableSchema#to_map_table_items[:keys]")
    assert_equal('9999'                    , map_items[TableSchema::INDEX_DEFAULT], "TableSchema#to_map_table_items[:default]")
    assert_equal(expected_auto_inc         , map_items[TableSchema::INDEX_EXTRA]  , "TableSchema#to_map_table_items[:extra]")
    assert_equal("virutal column 'columnA'", map_items[TableSchema::INDEX_COMMENT], "TableSchema#to_map_table_items[:comment]")

    name = 'columnB'
    column_schema = make_empty_column_schema(name, type='char', auto_increment=false)

    column_schema.instance_eval do
      @not_null = false
      @default = '9999'
      @comment = "virutal column 'columnB'"
    end

    table_schema = make_empty_table_schema
    map_items = nil
    table_schema.instance_eval do
      @primary_keys = ['column_other']
      f_key = Object.new
      f_key.instance_variable_set(:@name, 'column_other')
      def f_key.name; @name; end
      @foreign_keys = [f_key]
      map_items = to_map_table_items(column_schema)
    end

    assert_equal(name  , map_items[TableSchema::INDEX_NAME]   , "TableSchema#to_map_table_items[:name]")
    assert_equal(type  , map_items[TableSchema::INDEX_TYPE]   , "TableSchema#to_map_table_items[:type]")
    assert_equal(''    , map_items[TableSchema::INDEX_NULL]   , "TableSchema#to_map_table_items[:null]")
    assert_equal(""    , map_items[TableSchema::INDEX_KEYS]   , "TableSchema#to_map_table_items[:keys]")
    assert_equal('9999', map_items[TableSchema::INDEX_DEFAULT], "TableSchema#to_map_table_items[:default]")
    assert_equal(''    , map_items[TableSchema::INDEX_EXTRA]  , "TableSchema#to_map_table_items[:extra]")
    assert_equal("virutal column 'columnB'",
                         map_items[TableSchema::INDEX_COMMENT], "TableSchema#to_map_table_items[:comment]")
  end

  def test_parse_raw_line_of_class_table_schema
    table_schema = make_empty_table_schema

    table_schema.instance_eval do
      column1 = Object.new
      def column1.name; 'column1'; end
      @columns = [column1]
      @has_key = false
      @has_table_options = false
    end

    def table_schema.get_table_name_at_top(line)
      return line == 'table_name' ? 'table1' : nil
    end

    def table_schema.get_key(line)
      @has_key = true if line == 'key'
    end

    def table_schema.get_table_options(line)
      @has_table_options = true
    end

    assert_equal = method(:assert_equal)
    assert       = method(:assert)

    table_schema.instance_eval do
      parse_raw_line('table_name', capitalizes_types=false)
      assert_equal.call('table1', @name, "Table name from parse_raw_line()")
      assert_equal.call(%w(column1), @columns.map { |c| c.name })
      assert.call(! @has_key)
      assert.call(! @has_table_options)
    end

    raw_line = "`column2` int"
    table_schema.instance_eval do
      parse_raw_line(raw_line, capitalizes_types=false)
      assert_equal.call('table1', @name, "Table name from parse_raw_line()")
      assert_equal.call(%w(column1 column2), @columns.map { |c| c.name }, "@columns update after parse_raw_line()")
      assert_equal.call('int', @columns[-1].type, "Type of the column added last")
      assert.call(! @has_key)
      assert.call(! @has_table_options)
    end

    raw_line = "`column3` int"
    table_schema.instance_eval do
      parse_raw_line(raw_line, capitalizes_types=true)
      assert_equal.call('table1', @name, "Table name from parse_raw_line()")
      assert_equal.call(%w(column1 column2 column3), @columns.map { |c| c.name }, "@columns update after parse_raw_line()")
      assert_equal.call('INT', @columns[-1].type, "Type of the column added last")
      assert.call(! @has_key)
      assert.call(! @has_table_options)
    end

    table_schema.instance_eval do
      parse_raw_line('key', capitalizes_types=false)
      assert_equal.call('table1', @name, "Table name from parse_raw_line()")
      assert_equal.call(%w(column1 column2 column3), @columns.map { |c| c.name }, "@columns update after parse_raw_line()")
      assert.call(@has_key)
      assert.call(! @has_table_options)
    end

    table_schema.instance_eval do
      parse_raw_line('options', capitalizes_types=false)
      assert_equal.call('table1', @name, "Table name from parse_raw_line()")
      assert_equal.call(%w(column1 column2 column3), @columns.map { |c| c.name }, "@columns update after parse_raw_line()")
      assert.call(@has_key)
      assert.call(@has_table_options)
    end
  end

  def test_get_key_raises_exception
    table_schema = make_empty_table_schema

    line = "  PRIMARY KEY (`columnA`),"
    msg = "DuplicatePrimaryKeyException should have been raised"
    assert_raise(DuplicatePrimaryKeyException, msg) do
      table_schema.instance_eval do
        @primary_keys = %w(pk)
        get_key(line)
      end
    end

    line = "  PRIMARY KEY (`columnA`,`columnB`),"
    msg = "DuplicatePrimaryKeyException should have been raised"
    assert_raise(DuplicatePrimaryKeyException, msg) do
      table_schema.instance_eval do
        @primary_keys = %w(pk)
        get_key(line)
      end
    end
  end

  def test_get_key_for_primary_keys
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    line = "  PRIMARY KEY (`columnA`),"
    table_schema.instance_eval do
      get_key(line)
      assert_equal.call(%w(columnA), @primary_keys, "@primary_keys")
    end

    line = "  PRIMARY KEY (`columnA`,`columnB`,`columnC`),"
    table_schema.instance_eval do
      @primary_keys = Array.new
      get_key(line)
      assert_equal.call(%w(columnA columnB columnC), @primary_keys, "@primary_keys")
    end
  end

  def test_get_key_for_keys
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    line = "  KEY `key1` (`columnA`),"
    table_schema.instance_eval do
      @primary_keys = %w(pk)
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(1, @keys.size, "No. of keys")
      assert_equal.call('key1', @keys[0].name, "key name")
      column_names = @keys[0].column_names
      assert_equal.call(1, column_names.size, "No. of keys")
      assert_equal.call('columnA', column_names[0], "column name")
    end

    line = "  KEY `key2` (`columnA`,`columnB`,`columnC`),"
    table_schema.instance_eval do
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(2, @keys.size, "No. of keys")
      assert_equal.call('key1', @keys[0].name, "key name")
      assert_equal.call('key2', @keys[1].name, "key name")
      column_names = @keys[0].column_names
      assert_equal.call(1, column_names.size, "No. of keys")
      assert_equal.call('columnA', column_names[0], "column name")
      column_names = @keys[1].column_names
      assert_equal.call(3, column_names.size, "No. of keys")
      assert_equal.call(%w(columnA columnB columnC), column_names, "column names")
    end

    line = "  UNIQUE KEY `unique1` (`columnI`),"
    table_schema.instance_eval do
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(1, @unique_keys.size, "No. of unique keys")
      assert_equal.call('unique1', @unique_keys[0].name, "key name")
      column_names = @unique_keys[0].column_names
      assert_equal.call(1, column_names.size, "No. of unique keys")
      assert_equal.call('columnI', column_names[0], "column name")
    end

    line = "  UNIQUE KEY `unique2` (`columnI`,`columnJ`,`columnK`),"
    table_schema.instance_eval do
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(2, @unique_keys.size, "No. of unique keys")
      assert_equal.call('unique1', @unique_keys[0].name, "key name")
      assert_equal.call('unique2', @unique_keys[1].name, "key name")
      column_names = @unique_keys[0].column_names
      assert_equal.call(1, column_names.size, "No. of unique keys")
      assert_equal.call('columnI', column_names[0], "column name")
      column_names = @unique_keys[1].column_names
      assert_equal.call(3, column_names.size, "No. of unique keys")
      assert_equal.call(%w(columnI columnJ columnK), column_names, "column names")
    end
  end

  def test_get_key_for_foreign_keys
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    line = "  CONSTRAINT `fk1` FOREIGN KEY (`ext_id`) REFERENCES `ext` (`id`),  "
    table_schema.instance_eval do
      @primary_keys = %w(pk)
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(1, @foreign_keys.size, "No. of foreign keys")
      foreign_key = @foreign_keys[0]
      assert_equal.call('fk1'   , foreign_key.name, "foreign key name")
      assert_equal.call('ext_id', foreign_key.column_name, "column name of foreign key")
      assert_equal.call('ext'   , foreign_key.ref_table_name, "ref. table name of foreign key")
      assert_equal.call('id'    , foreign_key.ref_column_name, "ref. column name of foreign key")
    end

    line = "  CONSTRAINT `fk2` FOREIGN KEY (`out_id`) REFERENCES `out` (`id`),  "
    table_schema.instance_eval do
      @primary_keys = %w(pk)
      get_key(line)
      assert_equal.call(%w(pk), @primary_keys, "primary keys")
      assert_equal.call(2, @foreign_keys.size, "No. of foreign keys")
      foreign_key = @foreign_keys[0]
      assert_equal.call('fk1'   , foreign_key.name, "foreign key name")
      assert_equal.call('ext_id', foreign_key.column_name, "column name of foreign key")
      assert_equal.call('ext'   , foreign_key.ref_table_name, "ref. table name of foreign key")
      assert_equal.call('id'    , foreign_key.ref_column_name, "ref. column name of foreign key")
      foreign_key = @foreign_keys[1]
      assert_equal.call('fk2'   , foreign_key.name, "foreign key name")
      assert_equal.call('out_id', foreign_key.column_name, "column name of foreign key")
      assert_equal.call('out'   , foreign_key.ref_table_name, "ref. table name of foreign key")
      assert_equal.call('id'    , foreign_key.ref_column_name, "ref. column name of foreign key")
    end
  end

  def test_get_key_with_no_match
    table_schema = make_empty_table_schema

    assert = method(:assert)

    line = ""
    table_schema.instance_eval do
      assert.call(! get_key(line))
    end
  end

  def test_set_primary_keys_to_columns
    table_schema = make_empty_table_schema

    columns = Array.new
    columns << make_empty_column_schema('columnA')
    columns << make_empty_column_schema('columnB')
    columns << make_empty_column_schema('columnC')
    columns << make_empty_column_schema('columnD')
    table_schema.instance_eval do
      @columns = columns
    end

    assert = method(:assert)

    table_schema.instance_eval do
      @primary_keys = %w(columnE columnF)
      set_primary_keys_to_columns
      @columns.each do |column|
        assert.call(! column.primary_key?)
      end
    end

    table_schema.instance_eval do
      @primary_keys = %w(columnA columnE columnF)
      set_primary_keys_to_columns
      @columns.each do |column|
        if column.name == 'columnA'
          assert.call(  column.primary_key?)
        else
          assert.call(! column.primary_key?)
        end
      end
    end

    table_schema.instance_eval do
      @primary_keys = %w(columnB columnC columnD)
      set_primary_keys_to_columns
      @columns.each do |column|
        assert.call(column.primary_key?)
      end
    end
  end

  def test_sort_foreign_keys_by_column_order_with_empty
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    table_schema.instance_eval do
      @foreign_keys = Array.new
      sort_foreign_keys_by_column_order
      assert_equal.call([], @foreign_keys, "Empty @foreign_keys should have been unchanged")
    end
  end

  def test_sort_foreign_keys_by_column_order_with_empty
    table_schema = make_empty_table_schema

    make_fk      = method(:make_foreign_key_mock_with_column_name)
    make_column  = method(:make_empty_column_schema)
    assert_equal = method(:assert_equal)

    table_schema.instance_eval do
      @foreign_keys = Array.new
      %w(C B D A).each do |ch|
        @foreign_keys << make_fk.call('column' + ch)
      end

      @columns = Array.new
      %w(A B C D).each do |ch|
        @columns << make_column.call('column' + ch)
      end

      sort_foreign_keys_by_column_order
      expected = %w(A B C D).map { |ch| 'column' + ch }
      actual   = @foreign_keys.map { |fk| fk.column_name }
      assert_equal.call(expected, actual, "@foreign_keys sorted according to @columns")
    end
  end

    def make_foreign_key_mock_with_column_name(column_name)
      mock = Object.new
      mock.instance_variable_set(:@column_name, column_name)
      def mock.column_name
        @column_name
      end
      return mock
    end
    private :make_foreign_key_mock_with_column_name

  def test_set_default_column_comment_for_id
    table_schema = make_empty_table_schema

    assert = method(:assert)

    columns = Array.new
    columns << make_empty_column_schema('id'  , 'no type', auto_increment=true )
    columns << make_empty_column_schema('name', 'no type', auto_increment=false)
    table_schema.instance_eval do
      @columns = columns
      assert.call(all_columns_comments_blank?, "Confirmation of the initial status")
      set_default_column_comment_for_id
      assert.call(all_columns_comments_blank?, "Should be no change if @primary_keys.size > 1")
    end

    table_schema.instance_eval do
      @primary_keys = %w(1 2)
      set_default_column_comment_for_id
      assert.call(all_columns_comments_blank?, "Should be no change if all_columns_comments_blank?")
      @columns[1].comment = "This is COLUMN `name`"
      assert.call(! all_columns_comments_blank?, "Confirmation of the column comment addition")
    end

    table_schema.instance_eval do
      @primary_keys = %w(name)
      set_default_column_comment_for_id
      assert.call(@columns[0].comment_blank?, "Should be no change if primary key is not auto_increment")
    end

    assert_equal = method(:assert_equal)

    table_schema.instance_eval do
      @primary_keys = %w(id)
      set_default_column_comment_for_id
      assert.call(! @columns[0].comment_blank?, "Should be added with a comment if primary key with auto_increment")
      assert_equal.call(TableSchema::DEFAULT_COLUMN_COMMENT_FOR_ID, @columns[0].comment, "Added comment")
    end
  end

  def test_get_table_name_at_top_no_match
    table_schema = make_empty_table_schema

    [
      "CREATE TABLE `table name` (",
      "CREATE TABLE 'name' (",
    ].each do |line|
      msg = "Unexpected match for line \"#{line}\""
      assert_raise(CannotGetTableNameException, msg) do
        table_schema.instance_eval do
          get_table_name_at_top(line)
        end
      end
    end
  end

  def test_get_table_name_at_top
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    [
      "CREATE TABLE `name` (",
      "create table `name` (",
      "  CREATE   TABLE   `name`   (  ",
    ].each do |line|
      begin
        table_schema.instance_eval do
          name = get_table_name_at_top(line)
          assert_equal.call('name', name, "Table name from line \"#{line}\"")
        end
      rescue CannotGetTableNameException
        flunk("No match for line \"#{line}\"")
      end
    end
  end

  def test_get_table_options_no_match
    table_schema = make_empty_table_schema

    line = ""
    msg = "CannotGetTableOptionsException should have been raised"
    assert_raise(CannotGetTableOptionsException, msg) do
      table_schema.instance_eval do
        get_table_options(line)
      end
    end
  end

  def test_get_table_options
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)
    assert_nil   = method(:assert_nil  )

    line = ") engine=Honda auto_increment=23 default charset=jis97"
    begin
      table_schema.instance_eval do
        get_table_options(line)
        assert_equal.call('Honda', @engine         , "Engine")
        assert_equal.call('23'   , @auto_increment , "AUTO_INCREMENT")
        assert_equal.call('jis97', @default_charset, "Default charset")
        assert_nil  .call(         @collate        , "Collate")
        assert_nil  .call(         @max_rows       , "MAX_ROWS")
        assert_nil  .call(         @comment        , "Comment")
      end
    rescue CannotGetTableOptionsException
      flunk("No match for line \"#{line}\"")
    end
  end

  def test_get_table_options_full
    table_schema = make_empty_table_schema

    assert_equal = method(:assert_equal)

    line = "  )  engine=Honda  auto_increment=23  default charset=jis97" \
         + "  collate=england  max_rows=999  comment='No comment'  "
    begin
      table_schema.instance_eval do
        get_table_options(line)
        assert_equal.call('Honda'     , @engine         , "Engine")
        assert_equal.call('23'        , @auto_increment , "AUTO_INCREMENT")
        assert_equal.call('jis97'     , @default_charset, "Default charset")
        assert_equal.call('england'   , @collate        , "Collate")
        assert_equal.call('999'       , @max_rows       , "MAX_ROWS")
        assert_equal.call('No comment', @comment        , "Comment")
      end
    rescue CannotGetTableOptionsException
      flunk("No match for line \"#{line}\"")
    end
  end

  def test_add_table_options_as_xml
    table_schema = make_empty_table_schema

    xml_doc = prepare_xml_doc_with_root('root')

    table_schema.instance_eval do
      @engine          = 'Honda'
      @auto_increment  = '23'
      @default_charset = 'jis97'
      @collate         = 'england'
      @max_rows        = '999'
      @comment         = 'No comment'

      add_table_options_as_xml(xml_doc.root)
    end

    expected_lines = [
      "<?xml version='1.0' encoding='UTF-8'?>",
      "<root>",
        "<table_options>",
          "<engine>Honda</engine>",
          "<default_charset>jis97</default_charset>",
          "<collate>england</collate>",
          "<max_rows>999</max_rows>",
          "<comment>",
            "<![CDATA[No comment]]>",
          "</comment>",
        "</table_options>",
      "</root>",
    ]

    actual = Array.new
    xml_doc.write(actual)
    actual_lines = actual.join.split("><").join(">\n<").split("\n")

    assert_in_lines(expected_lines, actual_lines, "TableSchema#add_table_options_as_xml()")
  end

    def prepare_xml_doc_with_root(root_element_name)
      xml_doc = REXML::Document.new
      xml_doc.add(REXML::XMLDecl.new(version="1.0", encoding="utf-8"))

      root_element = REXML::Element.new(root_element_name)
      xml_doc.add_element(root_element)

      return xml_doc
    end
    private :prepare_xml_doc_with_root

  def test_constructor_of_class_table_schema_difference
    assert_equal = method(:assert_equal)

    namesABC = %w(columnA columnB columnC)
    [
      [namesABC, namesABC                   , []                 , []                         , namesABC           ],
      [namesABC, %w(columnA columnB columnD), %w(columnC)        , %w(columnD)                , %w(columnA columnB)],
      [namesABC, %w(columnA columnD columnE), %w(columnB columnC), %w(columnD columnE)        , %w(columnA)        ],
      [namesABC, %w(columnD columnE columnF), namesABC           , %w(columnD columnE columnF), []                 ],
    ].each do |column_names1, column_names2, column_names_only1, column_names_only2, column_names_both|
      table_schema1 = make_table_schema_mock(column_names1)
      table_schema2 = make_table_schema_mock(column_names2)
      ts_diff = TableSchemaDifference.new(table_schema1, table_schema2)
      ts_diff.instance_eval do
        assert_equal.call(column_names_only1, @column_names_only1, "columns in only1")
        assert_equal.call(column_names_only2, @column_names_only2, "columns in only2")
        assert_equal.call(column_names_both , @column_names_both , "columns in both" )
      end
    end
  end

    def make_table_schema_mock(column_names=[], primary_keys=[])
      mock = Object.new
      mock.instance_variable_set(:@column_names, column_names)
      mock.instance_variable_set(:@primary_keys, primary_keys)
      def mock.column_names
        @column_names
      end
      def mock.primary_keys
        @primary_keys
      end
      return mock
    end
    private :make_table_schema_mock

  #TODO: Test equals?, which was not finished as of 2010-05-21

  def test_column_names_equals_of_class_table_schema_difference
    namesABC = %w(columnA columnB columnC)
    [
      [[]      , []                         , true ],
      [%w(id)  , %w(id)                     , true ],
      [namesABC, %w(columnA columnB columnC), true ],
      [namesABC, %w(columnA columnB columnD), false],
      [namesABC, %w(columnI columnB columnC), false],
    ].each do |column_names1, column_names2, expected|
      table_schema1 = make_table_schema_mock(column_names1)
      table_schema2 = make_table_schema_mock(column_names2)
      ts_diff = TableSchemaDifference.new(table_schema1, table_schema2)
      assert_equal(expected, ts_diff.column_names_equals?, "TableSchemaDifference#column_names_equals?")
    end
  end

  def test_primary_keys_equals_of_class_table_schema_difference
    [
      [[]             , []             , true ],
      [%w(pk1)        , %w(pk1)        , true ],
      [%w(pk1)        , %w(pk2)        , false],
      [%w(pk1 pk2)    , %w(pk1 pk2)    , true ],
      [%w(pk1 pk2)    , %w(pk2 pk1)    , true ],
      [%w(pk1 pk2 pk3), %w(pk1 pk2 pk3), true ],
      [%w(pk1 pk2 pk3), %w(pk1 pk3 pk2), true ],
      [%w(pk1 pk2 pk3), %w(pk2 pk3 pk1), true ],
      [%w(pk1 pk2 pk3), %w(pk3 pk2 pk1), true ],
      [%w(pk1 pk2 pk3), %w(pk1 pk2 pk4), false],
    ].each do |primary_keys1, primary_keys2, expected|
      table_schema1 = make_table_schema_mock([], primary_keys1)
      table_schema2 = make_table_schema_mock([], primary_keys2)
      ts_diff = TableSchemaDifference.new(table_schema1, table_schema2)
      assert_equal(expected, ts_diff.primary_keys_equals?, "TableSchemaDifference#primary_keys_equals?")
    end
  end

  def test_primary_keys_1_or_2_of_class_table_schema_difference
    [
      [[]             , []             ],
      [%w(pk1 pk2 pk3), %w(pk4 pk5 pk6)],
    ].each do |primary_keys1, primary_keys2|
      table_schema1 = make_table_schema_mock([], primary_keys1)
      table_schema2 = make_table_schema_mock([], primary_keys2)
      ts_diff = TableSchemaDifference.new(table_schema1, table_schema2)
      assert_equal(primary_keys1, ts_diff.primary_keys1, "TableSchemaDifference#primary_keys1")
      assert_equal(primary_keys2, ts_diff.primary_keys2, "TableSchemaDifference#primary_keys2")
    end
  end
end

