reprint, total = 11, 100000

@memo = {}
def publish(reprint, total, pre)
  if @memo[[reprint, total, pre]]
    return @memo[[reprint, total, pre]]
  end
  return 0 if total < 0
  return (total == 0) ? 1 : 0 if reprint == 0
  cnt = 0
  1.upto(pre) do |i|
    cnt += publish(reprint - 1, total - i, i)
  end
  @memo[[reprint, total, pre]] = cnt
end

puts publish(reprint, total / 1000, total / 1000)
