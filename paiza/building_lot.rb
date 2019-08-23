require 'set'

require 'pry'


class Allocator
  attr_reader :buildings_not_used

  def self.build_from(input)
    f = StringIO.new(input.gsub(/^\s*/, ''))

    height, width, n_buildings = f.gets.split.map(&:to_i)
    Allocator.new(Lot.new(height, width)).tap { |allocator|
      n_buildings.times do |i|
        args = f.gets.split.map(&:to_i)
        allocator.add(Building.new(i + 1, *args))
      end
    }
  end

  def initialize(lot)
    @lot = lot
    @buildings = []
  end

  def add(building)
    @buildings << building unless oversize?(building)
  end

  def allocate
    @buildings.sort_by! { |b| -b.score }
    @buildings_not_used = []
    @buildings.each do |building|
      is_placed = @lot.place(building)
      @buildings_not_used << building unless is_placed
    end
  end

  def to_s(pretty = false)
    @lot.to_s(pretty)
  end

  private

    def oversize?(building)
      building.height > @lot.height || building.width > @lot.width
    end
end


class Lot
  attr_reader :height, :width

  def initialize(height, width)
    @height = height
    @width  = width
    @cells = Array.new(height) { Array.new(width) { Cell.new } }
  end

  def place(building)
    y0, x0, dy, dx, dir = y0_x0_dy_dx_and_dir_for(building)
    y, x = y0, x0
    while true
      if placeable?(building, y, x)
        do_place(building, y, x)
        return true if all_fronts_connected?
        undo_place(building, y, x)
      end
      if dir == :y
        y += dy
        if y < 0 || y >= @height
          y = y < 0 ? @height - 1 : 0
          x += dx
          break if out_of_bounds?(y, x)
        end
      else
        x += dx
        if x < 0 || x >= @width
          x = x < 0 ? @width - 1 : 0
          y += dy
          break if out_of_bounds?(y, x)
        end
      end
    end
    false
  end

  def to_s(pretty = false)
    @cells.map { |row|
      row.map { |cell|
        cell.to_s(pretty)
      }.join(pretty ? '' : ' ')
    }.join("\n")
  end

  private

    def out_of_bounds?(y, x)
      y < 0 || y >= @height || x < 0 || x >= @width
    end

    def all_fronts_connected?
      @cells.flatten.each do |cell|
        cell.unmark
      end
      Cell.clear_passway_connections

      @mark_id = 0
      prev_row = nil
      @cells.each do |row|
        mark_passway_in(row)
        connect_passway(prev_row, row)
        prev_row = row
      end

      entrances = @cells.flatten.find_all { |cell| cell.entrance? }
      entrances.each_cons(2) do |ent0, ent1|
        return false unless ent0.connected_with?(ent1)
      end
      true
    end

    def mark_passway_in(row)
      in_passway = false
      row.each do |cell|
        if cell.built?
          in_passway = false
          next
        end
        @mark_id += 1 unless in_passway
        in_passway = true
        cell.mark(@mark_id)
      end
    end

    def connect_passway(prev_row, row)
      return unless prev_row
      prev_row.zip(row) do |cell0, cell1|
        cell0.connect_with(cell1)
      end
    end

    def y0_x0_dy_dx_and_dir_for(building)
      case building.ent_direction
      when :north
        [@height - building.height, 0, -1,  1, change_side?(building) ? :y : :x]
      when :south
        [0, 0,                          1,  1, change_side?(building) ? :y : :x]
      when :west
        [0, @width - building.width,    1, -1, change_side?(building) ? :x : :y]
      else
        [0, 0,                          1,  1, change_side?(building) ? :x : :y]
      end
    end

    def change_side?(building)
      case building.ent_direction
      when :north
        !placeable_on?(:south, building) \
          && (placeable_on?(:west , building) || placeable_on?(:east , building))
      when :south
        !placeable_on?(:north, building) \
          && (placeable_on?(:west , building) || placeable_on?(:east , building))
      when :west
        !placeable_on?(:east, building) \
          && (placeable_on?(:north, building) || placeable_on?(:south, building))
      else
        !placeable_on?(:west, building) \
          && (placeable_on?(:north, building) || placeable_on?(:south, building))
      end
    end

    def placeable_on?(edge, building)
      case edge
      when :north, :south
        max_empty_edge_length_on(edge) >= building.width
      when :west, :east
        max_empty_edge_length_on(edge) >= building.height
      else
        raise "Illegal edge '#{edge}'"
      end
    end

    def max_empty_edge_length_on(edge)
      cells = case edge
              when :north
                @cells[0]
              when :south
                @cells[-1]
              when :west
                @cells.map { |row| row[0] }
              when :east
                @cells.map { |row| row[-1] }
              else
                raise "Illegal edge '#{edge}'"
              end
      max_empty_length_in(cells)
    end

    def max_empty_length_in(cells)
      cells.chunk { |cell| cell.buildable? }.find_all { |x| x[0] }.map { |x| x[1].size }.max || 0
    end

    def placeable?(building, y0, x0)
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      return false if y1 >= @height
      return false if x1 >= @width
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          cell = @cells[y][x]
          return false unless cell.buildable?
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      return false if out_of_bounds?(y_front, x_front)
      !@cells[y_front][x_front].built?
    end

    def do_place(building, y0, x0)
      raise "Cannot place #{building.inspect} at (#{y0}, #{x0})" unless placeable?(building, y0, x0)
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          @cells[y][x].build(building)
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      @cells[y_front][x_front].add_entrance_for(building)
    end

    def undo_place(building, y0, x0)
      return unless @cells[y0][x0].built?
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          @cells[y][x].unbuild
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      @cells[y_front][x_front].remove_entrance_for(building)
    end

  class Cell
    attr_reader :building_id, :mark_id

    def self.clear_passway_connections
      @@connection_sets = []
    end

    def initialize
      @building_id = 0
      @entrances = []
      @mark_id = nil
      @is_checked = false
    end

    def built?
      @building_id > 0
    end

    def entrance?
      @entrances.size > 0
    end

    def buildable?
      !built? && !entrance?
    end

    def build(building)
      @building_id = building.id
    end

    def unbuild
      @building_id = 0
    end

    def add_entrance_for(building)
      @entrances << building.id
    end

    def remove_entrance_for(building)
      @entrances.delete(building.id)
    end

    def marked?
      mark_id
    end

    def mark(id)
      @mark_id = id
    end

    def unmark
      @mark_id = nil
    end

    def connected_with?(other)
      mark_id == other.mark_id \
        || @@connection_sets.any? { |set| set.include?(mark_id) && set.include?(other.mark_id) }
    end

    def connect_with(other)
      return unless marked? && other.marked?

      connection_set = @@connection_sets.find { |set|
        set.include?(mark_id) || set.include?(other.mark_id)
      }
      if connection_set
        connection_set << mark_id << other.mark_id
      else
        @@connection_sets << Set.new([mark_id, other.mark_id])
      end
    end

    def to_s(pretty = false)
      if pretty
        @entrances.size >= 2 ? '#' : @entrances.size == 1 ? '+' \
          : @building_id.zero? ? '.' \
          : @building_id >= 10 ? ('A'.ord + @building_id - 10).chr \
          : @building_id.to_s
      else
        @building_id.to_s
      end
    end
  end
end


class Building
  attr_reader :id, :height, :width, :y_ent, :x_ent

  def initialize(id, height, width, y_ent, x_ent)
    @id     = id
    @height = height
    @width  = width
    @y_ent  = y_ent
    @x_ent  = x_ent
    _dump = ent_direction
  end

  def score
    @height * @width
  end

  def ent_direction
    if @y_ent == 1
      :north
    elsif @y_ent == @height
      :south
    elsif @x_ent == 1
      :west
    elsif @x_ent == @width
      :east
    else
      raise "Illegal entrance position (#{@y_ent}, #{@x_int}) for building ##{@id}"
    end
  end

  def coord_front_when_placed_on(y0, x0)
    case ent_direction
    when :north
      [y0 - 1, x0 + @x_ent - 1]
    when :south
      [y0 + @height, x0 + @x_ent - 1]
    when :west
      [y0 + @y_ent - 1, x0 - 1]
    else
      [y0 + @y_ent - 1, x0 + @width]
    end
  end

  def to_s
    id = @id
    id = ('A'.ord + id - 10).chr if id >= 10
    cells = Array.new(@height) { [' '] + [id] * @width + [' '] }
    cells.unshift([' '] * (@width + 2))
    cells.push(   [' '] * (@width + 2))
    y_front, x_front = coord_front_when_placed_on(1, 1)
    cells[y_front][x_front] = '+'
    cells.map { |row| row.join }.join("\n")
  end
end


module RandomInputMaker
  module_function

  def make(height_range, width_range, n_buildings_range, building_height_range, building_width_range)
    height      = determine_value(height_range)
    width       = determine_value(width_range)
    n_buildings = determine_value(n_buildings_range)
    strs = ["#{height} #{width} #{n_buildings}"]
    n_buildings.times do
      building_height = determine_value(building_height_range)
      building_width  = determine_value(building_width_range)
      y_x_ent_candidates = []
      2.upto(building_height - 1) do |y|
        y_x_ent_candidates << [y, 1]
        y_x_ent_candidates << [y, building_width]
      end
      2.upto(building_width - 1) do |x|
        y_x_ent_candidates << [1, x]
        y_x_ent_candidates << [building_height, x]
      end
      y_ent, x_ent = y_x_ent_candidates.sample
      strs << "#{building_height} #{building_width} #{y_ent} #{x_ent}"
    end
    strs.join("\n") + "\n"
  end

    def determine_value(range)
      return range unless range.is_a?(Range)
      rand(range)
    end
end


if __FILE__ == $0
  #$stdin = DATA

  reads_stdin = ARGV.empty?

  if reads_stdin
    input = $stdin.read
  else
    #input = RandomInputMaker.make(50, 50, 15..20, 7..15, 7..15)
    input = RandomInputMaker.make(100, 100, 30..40, 7..25, 7..25)

    puts input
    puts
  end

  allocator = Allocator.build_from(input)
  allocator.allocate

  if reads_stdin
    puts allocator
    puts
  end
  puts allocator.to_s(:pretty)
  puts

  allocator.buildings_not_used.each do |building|
    puts building
  end
end


__END__
6 7 3
2 4 2 3
2 5 2 3
3 2 2 1

2 3 1 2

5 7 4
3 5 3 3
3 5 2 1
3 5 2 5
3 5 1 3

5 5 2
2 5 2 2
2 5 1 3

