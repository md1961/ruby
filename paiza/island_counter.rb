$stdin = DATA


def mark_island(i_row, i_col, cells, i_island)
  return false unless cells[i_row][i_col].zero?
  cells[i_row][i_col] = i_island
  [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |d_row, d_col|
    mark_island(i_row + d_row, i_col + d_col, cells, i_island)
  end
  true
end

n_cols, n_rows = gets.split.map(&:to_i)
cells = []
cells << [-1] * (n_cols + 2)
n_rows.times do
  row = gets.chomp.split.map { |cell| cell == '0' ? -1 : 0 }
  cells << [-1] + row + [-1]
end
cells << [-1] * (n_cols + 2)

i_island = 1
1.upto(n_rows) do |i_row|
  1.upto(n_cols) do |i_col|
    is_marked = mark_island(i_row, i_col, cells, i_island)
    next unless is_marked
    i_island += 1
  end
end


cells.each do |row|
  puts row.map { |c| c < 0 ? '.' : c }.join(' ')
end


__END__
6 6
1 1 1 1 1 1
1 0 1 0 0 1
1 0 1 0 1 1
1 1 0 0 0 1
1 0 1 1 1 1
1 1 1 0 0 0

6 6
1 1 1 1 1 1
1 0 1 0 0 0
1 0 1 0 1 1
0 1 0 0 0 1
1 0 1 1 1 1
0 1 0 0 0 0

4 5
0 1 1 0
1 0 1 0
1 0 0 0
0 0 1 1
0 1 1 1
