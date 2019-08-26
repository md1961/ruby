require 'pry'


class Route
  attr_reader :i_from, :i_to, :fare

  def initialize(i_from, i_to, fare)
    @i_from = i_from
    @i_to   = i_to
    @fare   = fare
  end

  def include?(i_station)
    i_station == @i_from || i_station == @i_to
  end

  def copy_with_dest_to(i_station)
    raise "Do not include station ##{i_station}" unless include?(i_station)
    i_from, i_to = @i_from, @i_to
    i_from, i_to = i_to, i_from if i_to != i_station
    self.class.new(i_from, i_to, @fare)
  end

  def extend_back_with(other)
    new_i_from = i_from == other.i_to ? other.i_from : other.i_to
    self.class.new(new_i_from, i_to, fare + other.fare)
  end

  def ==(other)
    (i_from == other.i_from && i_to == other.i_to) || (i_from == other.i_to && i_to == other.i_from)
  end
end


if __FILE__ == $0

  $stdin = DATA

  i_start = 0
  n_routes, n_stations, i_dest = gets.split.map(&:to_i)
  fares = []
  n_routes.times do
    fares << Route.new(*gets.split.map(&:to_i))
  end

  routes_to_dest = fares.each_with_object([]) { |fare, routes|
    next unless fare.include?(i_dest)
    routes << fare.copy_with_dest_to(i_dest)
  }
  while true
    routes_to_dest = routes_to_dest.each_with_object([]) { |route, new_routes|
      i_from = route.i_from
      if i_from == i_start
        new_routes << route
      else
        fares.find_all { |fare| fare.include?(i_from) }.each do |route_back|
          next if route_back == route
          new_routes << route.extend_back_with(route_back)
        end
      end
    }

    h_min_fares_to_dest = routes_to_dest.each_with_object({}) { |route, h|
      h[route.i_from] = route.fare if !h[route.i_from] || route.fare < h[route.i_from]
    }

    routes_to_dest.reject! { |route| route.fare > h_min_fares_to_dest[route.i_from] }
    routes_to_dest.uniq! { |route| [route.i_from, route.i_to] }
    if h_min_fares_to_dest[i_start]
      routes_to_dest.reject! { |route| route.fare > h_min_fares_to_dest[i_start] }
    end

    break if routes_to_dest.size == 1 && routes_to_dest[0].i_from == i_start
  end

  puts routes_to_dest[0].fare
end


__END__
3 6 3
0 1 200
1 3 150
2 4 100

4 6 3
0 1 200
1 3 150
0 3 350
2 4 100

5 5 3
0 1 200
0 4 500
0 2 200
1 4 200
4 3 300

