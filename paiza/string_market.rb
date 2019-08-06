require 'forwardable'

class StringMarket
  extend Forwardable

  def initialize
    @root_hash_node = HashNode.new
  end

  def_delegators :@root_hash_node, :price_of, :add

  class HashNode

    def initialize
      @h_node = Hash.new { |h, k| h[k] = Node.new }
    end

    def price_of(query)
      char = query[0]
      node = @h_node[char]
      return node.price if query.length == 1
      node.hash_node.price_of(query[1 .. -1])
    end

    def add(str, price)
      return if str.empty?
      char = str[0]
      @h_node[char] = Node.new unless @h_node.key?(char)
      node = @h_node[char]
      node.add_price(price)
      node.hash_node.add(str[1 .. -1], price)
    end
  end

  class Node
    attr_reader :price, :hash_node

    def initialize
      @price = 0
      @hash_node = HashNode.new
    end

    def add_price(price)
      @price += price
    end
  end
end


if __FILE__ == $0
  n_strings, n_queries = gets.split.map(&:to_i)

  string_market = StringMarket.new
  n_strings.times do
    str, price = gets.split
    string_market.add(str, price.to_i)
  end

  n_queries.times do
    puts string_market.price_of(gets.chomp)
  end
end


__END__
1 1
aa 1
ab

6 5
bcac 3
abcd 14
abccjg 92
bcaddgie 2
abcd 6
cb 200
b
a
abcd
gagioheo
cb

5 3
paiza 16
pizza 1
paizaio 4
paizapoh 2
pizzaio 8
paiza
pizza
p

