def describe(target)
  yield if block_given?
end

def it(behavior)
  yield if block_given?
end

module Test
  module_function

  def assert_equals(actual, expected)
    if actual == expected
      puts 'OK'
    else
      puts "NG: Got '#{actual}', while '#{expected}' expected"
    end
  end
end
