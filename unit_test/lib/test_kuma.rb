
require 'test/unit'

require 'kuma'


class TestKumaStrUtil < Test::Unit::TestCase

  def test_non_empty_string
    false_args = [
      [nil], [""], [nil, ""], ["", nil], [" ", "  "]
    ]
    false_args.each do |arg|
      arg_display = arg.inspect[1 .. -2]
      msg = "non_empty_string?(#{arg_display}) should be false"
      assert(! Kuma::StrUtil.non_empty_string?(*arg), msg)
    end
  end
end

