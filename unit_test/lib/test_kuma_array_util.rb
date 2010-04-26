
require 'test/unit'

require 'kuma'


class TestKumaArrayUtil < Test::Unit::TestCase

  def test_split
    data = [
      [[],  1, []],
      [[],  2, []],
      [[], 10, []],
      [%w(abc),  1, [%w(abc)]],
      [%w(abc),  2, [%w(abc)]],
      [%w(abc), 10, [%w(abc)]],
      [%w(ab cd ef gh ij kl mn),  1, [%w(ab), %w(cd), %w(ef), %w(gh), %w(ij), %w(kl), %w(mn)]],
      [%w(ab cd ef gh ij kl mn),  2, [%w(ab cd), %w(ef gh), %w(ij kl), %w(mn)]],
      [%w(ab cd ef gh ij kl mn),  3, [%w(ab cd ef), %w(gh ij kl), %w(mn)]],
      [%w(ab cd ef gh ij kl mn),  4, [%w(ab cd ef gh), %w(ij kl mn)]],
      [%w(ab cd ef gh ij kl mn),  5, [%w(ab cd ef gh ij), %w(kl mn)]],
      [%w(ab cd ef gh ij kl mn),  6, [%w(ab cd ef gh ij kl), %w(mn)]],
      [%w(ab cd ef gh ij kl mn),  7, [%w(ab cd ef gh ij kl mn)]],
      [%w(ab cd ef gh ij kl mn),  8, [%w(ab cd ef gh ij kl mn)]],
      [%w(ab cd ef gh ij kl mn), 10, [%w(ab cd ef gh ij kl mn)]],
    ]
    data.each do |array, size, expected|
      actual = Kuma::ArrayUtil.split(array, size)
      assert_equal(expected, actual, "Array to split = #{array.inspect}")
    end
  end
end

