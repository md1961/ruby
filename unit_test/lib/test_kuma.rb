
require 'test/unit'

require 'kuma'


class TestKumaStrUtil < Test::Unit::TestCase

  def test_non_empty_string_to_be_false
    [
      [nil], [""], [nil, ""], ["", nil], [nil, " "], [" ", nil], [" ", "", nil],
      [1], [1, " "], [" ", 1], ["a", " ", 1],
    ].each do |arg|
      msg = "Kuma::StrUtil.non_empty_string?(#{arg_display(arg)}) should be false"
      assert(! Kuma::StrUtil.non_empty_string?(*arg), msg)
    end
  end

  def test_non_empty_string_to_be_true
    [
      [" "], ["a"], [" ", "a"], [" ", "a", "."],
    ].each do |arg|
      msg = "Kuma::StrUtil.non_empty_string?(#{arg_display(arg)}) should be true"
      assert(Kuma::StrUtil.non_empty_string?(*arg), msg)
    end
  end

    # remove '[' and ']' at both end from arg.inspect
    def arg_display(arg)
      return arg.inspect[1 .. -2]
    end
    private :arg_display

  def test_displaying_length_raise_exception
    [
      1, 3.14, [], {},
    ].each do |arg|
      begin
        Kuma::StrUtil.displaying_length(arg)
        flunk("Kuma::StrUtil.displaying_length(#{arg.inspect}) should raise an ArgumentError")
      rescue ArgumentError => e
      end
    end
  end
end

