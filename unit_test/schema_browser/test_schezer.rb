
require 'test/unit'

require 'schezer'


class TestSchezer < Test::Unit::TestCase

  BASE_DIR = "#{ENV['HOME']}/ruby/unit_test/schema_browser"
  CONF_FILE = "#{BASE_DIR}/db/schezer_test.yml"

  TABLE_NAMES_DEVEL = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)
  TABLE_NAMES_PROD  = %w(base_unit field fluid reserve reserve_header reservoir unit user)

  def test_get_table_names_from_argv_raise_exception
    no_table_names_devel = %w(field_office reserve_commentary user role)
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

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

  def test_get_table_names_from_argv
    table_names = call_get_table_names_from_argv(:development)
    assert_equal(TABLE_NAMES_DEVEL, table_names)

    table_names = call_get_table_names_from_argv(:production)
    assert_equal(TABLE_NAMES_PROD , table_names)
  end

    def call_get_table_names_from_argv(environment)
      schezer = Schezer.new(['-f', CONF_FILE, '-e', environment.to_s, 'names'])

      table_names = nil
      schezer.instance_eval do
        @argv = [Schezer::DEFAULT_TABLE_NAME]
        table_names = get_table_names_from_argv(@conn)
      end

      return table_names
    end
    private :call_get_table_names_from_argv

  def test_table_name2str_regexp_raise_exception
    illegal_patterns = %w('abc'de' "fg"hij" !klm!no!)
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

    illegal_patterns.each do |pattern|
      assert_raise(ExitWithMessageException, "Should have thrown an ExitWithMessageException") do
        schezer.instance_eval do
          table_name2str_regexp(pattern)
        end
      end
    end
  end

  def test_table_name2str_regexp_return_nil
    no_patterns = %w(abc reserve user)
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

    no_patterns.each do |pattern|
      actual = ''
      schezer.instance_eval do
        actual = table_name2str_regexp(pattern)
      end
      assert_nil(actual, "table_name2str_regexp(\"#{pattern}\") should be nil")
    end
  end

  def test_table_name2str_regexp
    legal_patterns = %w('abcde' "fghij" !klmno! ab* a.b ^ab ab$ ab?)
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

    legal_patterns.each do |pattern|
      actual = nil
      schezer.instance_eval do
        actual = table_name2str_regexp(pattern)
      end
      assert_not_nil(actual, "table_name2str_regexp(\"#{pattern}\") should be non-nil")
    end
  end

  def test_do_command_raise_exception
    no_commands = [:make, :delete, :remove]
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

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
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development sql_sync))
    assert_raise(ExitWithMessageException, "Should have thrown an ExitWithMessageException") do
      schezer.instance_eval do
        to_disp_sql_to_sync([], [])
      end
    end
  end

  def test_to_disp_sql_to_sync
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development -g production sql_sync))

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
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development sql_sync))

    column = Object.new
    def column.name           ; return 'id'; end
    def column.numerical_type?; return true; end
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

    column = Object.new
    def column.name           ; return 'type'; end
    def column.numerical_type?; return false ; end
    actual = nil
    schezer.instance_eval do
      actual = value_in_sql({'type' => 'field'}, column)
    end
    assert_equal("'field'", actual)
  end

  def test_make_values_for_sql_insert
  end

end

