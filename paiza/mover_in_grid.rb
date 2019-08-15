$stdin = DATA


d_move = {
  U: [ 1,  0],
  D: [-1,  0],
  R: [ 0,  1],
  L: [ 0, -1]
}

height, width, n_moves = gets.split.map(&:to_i)
y, x = [0, 0]
n_moves.times do
  move = gets.chomp.to_sym
  dy, dx = d_move[move]
  raise "Illegal move '#{move}'" unless dy
  y += dy
  x += dx
  if y < 0 || y >= height || x < 0 || x >= width
    puts 'invalid'
    exit
  end
end
puts 'valid'


__END__
4 4 7
U
U
R
R
R
R
D
