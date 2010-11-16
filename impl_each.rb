
module ImplEach
  def each
    @eachees.each do |eachee|
      yield eachee
    end
  end
end


class TestEach
  include ImplEach, Enumerable

  def initialize(*args)
    @eachees = args.dup
  end
end


if __FILE__ == $0
  te = TestEach.new(*((0 .. 9).to_a))

  te.each_with_index do |item, index|
    puts "item = #{item}, index = #{index}"
  end

  iter = te.each
  begin
    while true
      puts "item = #{iter.next}"
    end
  rescue StopIteration
  end
end

