$stdin = DATA


require 'pry'


n, n_fingers = gets.split.map(&:to_i)
opp_hands = gets.chomp
raise "n (#{n}) not match #{opp_hands.size}" unless n == opp_hands.size
n_opp_g = opp_hands.count('G')
n_opp_c = opp_hands.count('C')
n_opp_p = opp_hands.count('P')

max_wins = 0
0.upto(n_fingers / 5) do |n_own_p|
  n_own_c, mod = (n_fingers - n_own_p * 5).divmod(2)
  next if mod.nonzero? || (n_own_c + n_own_p) > n
  n_own_g = n - n_own_c - n_own_p
  wins_g = [n_own_g, n_opp_c].min
  wins_c = [n_own_c, n_opp_p].min
  wins_p = [n_own_p, n_opp_g].min
  wins = wins_g + wins_c + wins_p
  max_wins = wins if wins > max_wins
end
puts max_wins


__END__
245 1214
CCGGPCCPGCCCPCCCPPCPPCGGCGCGCCPGGPCGGGCPCPGGPCCPPCCGPPGGGPPCPGGPPGCPGCCCGCCPCPCPCPCGPCGGCGPGCGGGCGCCGPCCGPGCCCPCCPPPPPPGGCGPCGGGCGGGGPPPCPGGCCCGCGCPGGCPCCGCCCPPPPPCGCCCPPCPPPCCPGCCPGGCPCCCPGCPGGGPCGGPPGPGCPPPGCCCGCGPPCPCPPPPCPCCPPPPPCCCCPPPPPCGP

5 10
GPCPC

4 7
CGPC

