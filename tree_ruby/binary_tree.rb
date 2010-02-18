
class BinaryTree

  SELF  = 'self'
  LEFT  = 'left'
  RIGHT = 'right'
  MAX   = 'max'
  MIN   = 'min'

  module ValueComparator
    def left_smaller?(node1, node2)
      node1.value < node2.value || (node1.value == node2.value && left_when_equal?)
    end
  end

  # 小さいものは左へ、大きいものは右へ
  module SimpleLeftOrRightStrategy
    include ValueComparator

    def to_where_on_insert(node, node_to)
      left_smaller?(node, node_to) ? LEFT : RIGHT
    end
  end

  include SimpleLeftOrRightStrategy

  def self.left?(node, node_from)
    node.value < node_from.value || (node.value == node_from.value && @@left_when_equal)
  end

  def initialize(value_class, left_when_equal=true)
    @@value_class = value_class
    @@left_when_equal = left_when_equal
    @root_node = nil
  end

  def sorted?
    return @root_node.nil? || ! @root_node.max_or_min_value_if_sorted(true, @@left_when_equal).nil?
  end

  def num_nodes(which=SELF)
    return @root_node.nil? ? 0 : @root_node.num_nodes(which)
  end

  def height(which=SELF)
    return @root_node.nil? ? 0 : which == SELF ? @root_node.height : @root_node.height_of(which)
  end

  def balanced?
    @root_node.nil? || @root_node.balanced?
  end

  def add(value)
    unless value.class == @@value_class
      raise ArgumentError.new("Argument value must be of class #{@@value_class} (#{value.class} given)")
    end

    new_node = TreeNode.new(value)
    if @root_node.nil?
      @root_node = new_node
    else
      insert(new_node, @root_node)
    end
  end

  def rotate
    @root_node.rotate_unless_solely_balanced unless @root_node.nil?
  end

  def to_s
    return "no node" if @root_node.nil?
    @root_node.to_s
  end

  private

    SUFFIX_NO_CHILD = '/'

    def left_when_equal?
      @@left_when_equal
    end
  
    def insert(node, node_to)
      raise ArgumentError.new("Argument node_to must be non-nil") if node_to.nil?

      to_where = to_where_on_insert(node, node_to)
      if to_where == LEFT && node_to.left.nil?
        node_to.left = node
        node.parent  = node_to
      elsif to_where == RIGHT && node_to.right.nil?
        node_to.right = node
        node.parent   = node_to
      elsif [LEFT, RIGHT].include?(to_where)
        if to_where == LEFT
          insert(node, node_to.left)
        else
          insert(node, node_to.right)
        end
      else
      #elsif [PUSH_LEFT, PUSH_RIGHT].include?(to_where)
        node.copy_pointers_from(node_to)
        node_to.clear_pointers
        if to_where == PUSH_LEFT
          insert(node_to, node.left)
        else
          insert(node_to, node.right)
        end
      end
    end

  class TreeNode
    attr_accessor :value
    attr_reader :parent, :left, :right

    def self.cleanse(node)
      return node if node.nil? || node.class == TreeNode
      raise ArgumentError.new("Argument must be nil or TreeNode (#{node.class} given)")
    end

    def self.opposite(side)
      side == LEFT ? RIGHT : LEFT
    end

    def initialize(value, parent=nil, left=nil, right=nil)
      @value = value
      self.parent = parent
      self.left   = left
      self.right  = right
    end

    def node(side)
      return side == LEFT ? @left : @right
    end

    def no_child?
      return @left.nil? && @right.nil?
    end

    def num_nodes(which=SELF)
      num_left  = @left .nil? || which == RIGHT ? 0 : @left .num_nodes
      num_right = @right.nil? || which == LEFT  ? 0 : @right.num_nodes
      return num_left + num_right + (which == SELF ? 1 : 0)
    end

    def height
      height_left  = height_of(LEFT)
      height_right = height_of(RIGHT)
      return [height_left, height_right].max + 1
    end

    def balanced?
      height_left  = height_of(LEFT)
      height_right = height_of(RIGHT)
      is_left_balanced  = @left .nil? || @left .balanced?
      is_right_balanced = @right.nil? || @right.balanced?
      is_self_balanced  = (height_left - height_right).abs <= 1
      return is_left_balanced && is_right_balanced && is_self_balanced
    end

    def solely_balanced?
      return (height_of(LEFT) - height_of(RIGHT)).abs <= 1
    end

    def height_of(side)
      node = side == LEFT ? @left : @right
      return node.nil? ? 0 : node.height
    end

    def leftmost_or_rightmost_higher_of_four?
      return false if balanced?
      higher_side = height_of(LEFT) > height_of(RIGHT) ? LEFT : RIGHT
      child = node(higher_side)
      return child.height_of(higher_side) > child.height_of(TreeNode.opposite(higher_side))
    end

    def parent=(node)
      @parent = TreeNode.cleanse(node)
    end

    def left=(node)
      @left = TreeNode.cleanse(node)
    end

    def right=(node)
      @right = TreeNode.cleanse(node)
    end

    def set(node, side)
      case side
      when LEFT
        @left = node
      when RIGHT
        @right = node
      end
    end

    def rotate
      direction = height_of(LEFT) > height_of(RIGHT) ? RIGHT : LEFT
      if leftmost_or_rightmost_higher_of_four?
        avl_rotate(direction)
      else
        avl_rotate_double(direction)
      end
    end

    def rotate_unless_solely_balanced
      rotate unless solely_balanced?
      @left .rotate_unless_solely_balanced unless @left .nil?
      @right.rotate_unless_solely_balanced unless @right.nil?
    end

    def avl_rotate(direction)
      opposite = TreeNode.opposite(direction)
      child_to_be_root = node(opposite)
      self.value, child_to_be_root.value = child_to_be_root.value, self.value
      # Now child_to_be_root has become former_root
      former_root = child_to_be_root
      self.set(former_root.node(opposite), opposite)
      former_root.set(former_root.node(direction), opposite)
      former_root.set(self.node(direction), direction)
      self.set(former_root, direction)
    end

    def avl_rotate_double(direction)
      opposite = TreeNode.opposite(direction)
      grandchild_to_go_up = node(opposite).node(direction)
      node(opposite).set(grandchild_to_go_up.node(opposite), direction)
      grandchild_to_go_up.set(node(opposite), opposite)
      self.set(grandchild_to_go_up, opposite)

      avl_rotate(direction)
    end

    def copy_pointers_from(other)
      self.parent = other.parent
      self.left   = other.left
      self.right  = other.right
    end

    def clear_pointers
      self.parent = nil
      self.left   = nil
      self.right  = nil
    end

    NODE_IS_NULL = 'node_is_null'

    # 自分および自分の子孫すべてについて、自分より小さいものは左側、
    # 自分より大きいものは右側となっていれば、自分および自分の子孫全ての
    # 最大値を返す。なっていなければ、nil を返す
    def max_or_min_value_if_sorted(max_or_min, left_when_equal)
      max_left  = @left .nil? ? NODE_IS_NULL : @left .max_or_min_value_if_sorted(MAX, left_when_equal)
      min_right = @right.nil? ? NODE_IS_NULL : @right.max_or_min_value_if_sorted(MIN, left_when_equal)
      return nil if max_left.nil? || min_right.nil?
      return nil if max_left  != NODE_IS_NULL && (max_left  > @value || (max_left  == @value && ! left_when_equal))
      return nil if min_right != NODE_IS_NULL && (min_right < @value || (min_right == @value &&   left_when_equal))
      values = [max_left, @value, min_right].select { |x| x != NODE_IS_NULL }
      return max_or_min == MAX ? values.max : values.min
    end
   
    def nil_safe_node_value(node)
      node.nil? ? '-' : node.value.to_s + (node.no_child? ? SUFFIX_NO_CHILD : '')
    end

    def to_s
      strbuf = Array.new
      depth = 1
      strbuf << "##{depth}: (#{nil_safe_node_value(self)})"
      depth += 1
      nodes = no_child? ? [] : [self]
      while nodes.size > 0
        strbuf << "##{depth}: " + nodes.map { |node|
          "#{node.value}->(#{nil_safe_node_value(node.left)}, #{nil_safe_node_value(node.right)})"
        }.join(', ')
        nodes = nodes.dup.inject(Array.new) { |result, node|
          result << node.left  unless node.left .nil? || node.left .no_child?
          result << node.right unless node.right.nil? || node.right.no_child?
          result
        }
        depth += 1
      end
      return strbuf.join("\n")
    end
  end
end

class Array
  def sum
    return self.inject(0) { |result, element| result + element }
  end
end

