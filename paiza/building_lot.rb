require 'pry'


class Allocator

  def initialize(lot)
    @lot = lot
    @buildings = []
  end

  def add(building)
    @buildings << building unless oversize?(building)
  end

  def allocate
    @buildings.sort_by! { |b| -b.score }
    @buildings.each do |building|
      @lot.place(building)
    end
  end

  def to_s
    @lot.to_s
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
    @cells = Array.new(height) { [0] * width }
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

  def to_s
    @cells.map { |row|
      row.map { |cell|
        cell.is_a?(Array) ? (cell.size > 1 ? '#' : '+') \
          : cell.zero? ? '.' : cell >= 10 ? ('A'.ord + cell - 10).chr : cell
      }.join(' ')
    }.join("\n")
  end

  private

    def out_of_bounds?(y, x)
      y < 0 || y >= @height || x < 0 || x >= @width
    end

    def all_fronts_connected?
      num_buildings == num_fronts_connected_to_first_front
    end

    def num_buildings
      @cells.flat_map { |row|
        row.map { |cell| cell.is_a?(Array) ? 0 : cell }
      }.uniq.size - 1
    end

    def num_fronts_connected_to_first_front
      y0, x0 = coord_of_first_front
      return 0 unless y0
      num_fronts_connected_at(y0, x0).tap {
        clear_all_checked_marks
      }
    end

    def num_fronts_connected_at(y, x)
      return 0 if out_of_bounds?(y, x)
      return 0 if checked?(y, x)
      cell = @cells[y][x]
      return 0 if !cell.is_a?(Array) && cell > 0
      num0 = cell.is_a?(Array) ? cell.size : 0
      mark_check_at(y, x)
      [[-1, 0], [1, 0], [0, -1], [0, 1]].reduce(num0) { |num, (dy, dx)|
        num + num_fronts_connected_at(y + dy, x + dx)
      }
    end

    CHECK_MARK = :CHECKED

    def checked?(y, x)
      Array(@cells[y][x]).include?(CHECK_MARK)
    end

    def mark_check_at(y, x)
      cell = @cells[y][x]
      if cell == 0
        @cells[y][x] = CHECK_MARK
      elsif cell.is_a?(Array)
        cell << CHECK_MARK
      end
    end

    def clear_all_checked_marks
      0.upto(@height - 1) do |y|
        0.upto(@width - 1) do |x|
          cell = @cells[y][x]
          if cell.is_a?(Array) && cell.include?(CHECK_MARK)
            @cells[y][x].delete(CHECK_MARK)
          elsif cell == CHECK_MARK
            @cells[y][x] = 0
          end
        end
      end
    end

    def coord_of_first_front
      0.upto(@height - 1) do |y|
        0.upto(@width - 1) do |x|
          return [y, x] if @cells[y][x].is_a?(Array)
        end
      end
      nil
    end

    def y0_x0_dy_dx_and_dir_for(building)
      case building.ent_direction
      when :north
        dir = if !placeable_on?(:south, building) \
                  && (placeable_on?(:west, building) || placeable_on?(:east, building))
                :y
              else
                :x
              end
        [@height - building.height, 0, -1, 1, dir]
      when :south
        dir = if !placeable_on?(:north, building) \
                  && (placeable_on?(:west, building) || placeable_on?(:east, building))
                :y
              else
                :x
              end
        [0, 0, 1, 1, dir]
      when :west
        dir = if !placeable_on?(:east, building) \
                  && (placeable_on?(:north, building) || placeable_on?(:south, building))
                :x
              else
                :y
              end
        [0, @width - building.width, 1, -1, dir]
      else
        dir = if !placeable_on?(:west, building) \
                  && (placeable_on?(:north, building) || placeable_on?(:south, building))
                :x
              else
                :y
              end
        [0, 0, 1, 1, dir]
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
      cells.chunk { |cell| cell == 0 }.find_all { |x| x[0] }.map { |x| x[1].size }.max || 0
    end

    def placeable?(building, y0, x0)
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      return false if y1 >= @height
      return false if x1 >= @width
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          cell = @cells[y][x]
          return false if cell.is_a?(Array) || cell > 0
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      return false if out_of_bounds?(y_front, x_front)
      cell_front = @cells[y_front][x_front]
      cell_front.is_a?(Array) || cell_front == 0
    end

    def do_place(building, y0, x0)
      raise "Cannot place #{building.inspect} at (#{y0}, #{x0})" unless placeable?(building, y0, x0)
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          @cells[y][x] = building.id
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      cell_front = @cells[y_front][x_front]
      if cell_front == 0
        @cells[y_front][x_front] = [building.id]
      else
        cell_front << building.id
      end
    end

    def undo_place(building, y0, x0)
      return if @cells[y0][x0] != building.id
      y1 = y0 + building.height - 1
      x1 = x0 + building.width  - 1
      y0.upto(y1) do |y|
        x0.upto(x1) do |x|
          @cells[y][x] = 0
        end
      end
      y_front, x_front = building.coord_front_when_placed_on(y0, x0)
      @cells[y_front][x_front].delete(building.id)
      @cells[y_front][x_front] = 0 if @cells[y_front][x_front].empty?
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
end


if __FILE__ == $0
  $stdin = DATA

  height, width, n_buildings = gets.split.map(&:to_i)
  allocator = Allocator.new(Lot.new(height, width))

  n_buildings.times do |i|
    args = gets.split.map(&:to_i)
    allocator.add(Building.new(i + 1, *args))
  end

  allocator.allocate

  puts allocator
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

