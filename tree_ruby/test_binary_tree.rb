
require 'binary_tree'

bt = BinaryTree.new(1.class)

=begin
bt.add(50)
bt.add(60)
bt.add(52)

puts bt
puts "The tree is #{bt.sorted? ? '' : 'NOT '}sorted."
printf("No. of nodes on the left = %d, right = %d\n", bt.num_nodes(BinaryTree::LEFT), bt.num_nodes(BinaryTree::RIGHT))
printf("height on the left = %d, right = %d\n", bt.height(BinaryTree::LEFT), bt.height(BinaryTree::RIGHT))

bt.rotate
puts bt
puts "The tree is #{bt.sorted? ? '' : 'NOT '}sorted."
printf("No. of nodes on the left = %d, right = %d\n", bt.num_nodes(BinaryTree::LEFT), bt.num_nodes(BinaryTree::RIGHT))
printf("height on the left = %d, right = %d\n", bt.height(BinaryTree::LEFT), bt.height(BinaryTree::RIGHT))
=end

max_num = 100
num = 32
numbers = [6, 40, 76, 51, 55, 80, 2]
rands = []

USE_RAND = true

f = Proc.new { |rand|
  puts bt
  puts "balanced? = #{bt.balanced?}"

  rand = rand(max_num) if USE_RAND
  rands << rand
  bt.add(rand)
  puts "rands = [#{rands.join(', ')}]"
  puts bt
  puts "balanced? = #{bt.balanced?}"

  bt.rotate
}

USE_RAND ? num.times(&f) : numbers.each(&f)

puts bt
puts "balanced? = #{bt.balanced?}"
puts "The tree is #{bt.sorted? ? '' : 'NOT '}sorted."
printf("No. of nodes on the left = %d, right = %d\n", bt.num_nodes(BinaryTree::LEFT), bt.num_nodes(BinaryTree::RIGHT))
#printf("height on the left = %d, right = %d\n", bt.height(BinaryTree::LEFT), bt.height(BinaryTree::RIGHT))

