require 'forwardable'

class RaisingHash
  extend Forwardable

  def_delegators(:@hash, :[]=, :empty?, :has_key?, :each, :delete, :keys, :values, :size)

=begin
  Hash.public_instance_methods(false).each do |name|
    define_method(name) do |*args, &block|
      @hash.send(name, *args, &block)
    end
  end
=end

  def initialize
    @hash = {}
  end

  def [](key)
    value = @hash[key]
    raise KeyError if value.nil?
    value
  end

  def freeze
    @hash.freeze
    super
  end

=begin
    def method_missing(name, *args, &block)
      if @hash.respond_to?(name)
        @hash.send(name, *args, &block)
      else
        super
      end
    end
    private :method_missing
=end
end
