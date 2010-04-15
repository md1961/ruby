
require 'test/unit'

require 'schezer'


class TestKumaStrUtil < Test::Unit::TestCase

  BASE_DIR = "#{ENV['HOME']}/ruby/unit_test/schema_browser"
  CONF_FILE = "#{BASE_DIR}/db/schezer_test.yml"

  TABLE_NAMES = %w(base_unit field fluid reserve reserve_header reserve_header_trash reservoir unit)

  def test_get_table_names_from_argv
    schezer = Schezer.new(['-f', CONF_FILE] + %w(-e development names))

    table_names = nil
    schezer.instance_eval do
      @argv = [Schezer::DEFAULT_TABLE_NAME]
      table_names = get_table_names_from_argv(@conn, nil)
    end

    assert_equal(TABLE_NAMES, table_names)
  end
end

