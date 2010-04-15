
require 'test/unit'

require 'schezer'


class TestSchezer < Test::Unit::TestCase

  BASE_DIR = "#{ENV['HOME']}/ruby/unit_test/schema_browser"
  CONF_FILE = "#{BASE_DIR}/db/schezer_test.yml"

  TABLE_NAMES_DEVEL = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)
  TABLE_NAMES_PROD  = %w(base_unit field fluid reserve reserve_header reservoir unit)

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
        table_names = get_table_names_from_argv(@conn, nil)
      end

      return table_names
    end
    private :call_get_table_names_from_argv
end

