class Morse
  def self.encode(message)
    bits = message.chars.map { |c|
      @alpha[c]
    }.join(CHAR_SEP)
    (bits + '0' * 31).chars.each_slice(32).map { |b|
      next unless b.size == 32
      bits_to_int(b.join)
    }.compact
  end

  def self.decode(array)
    bits = array.map { |n| format('%.32b', n)[-32..-1].gsub('.', '1') }.join
    bits.sub!(/0+\z/, '')
    bits.split(WORD_SEP).map { |b_word|
      b_word.split(CHAR_SEP).map { |b_char|
        @alpha.invert[b_char]
      }.join
    }.join(' ')
  end
  
    def self.bits_to_int(str_bits)
      if str_bits[0] == '0' 
        str_bits.to_i(2)
      else
        b_rev = str_bits[1..-1].chars.map { |c| c == '0' ? 1 : 0 }.map(&:to_s).join
        (b_rev.to_i(2) + 1) * -1
      end
    end

  @alpha={
    'A'=> '10111',
    'B'=> '111010101',
    'C'=> '11101011101',
    'D'=> '1110101',
    'E'=> '1',
    'F'=> '101011101',
    'G'=> '111011101',
    'H'=> '1010101',
    'I'=> '101',
    'J'=> '1011101110111',
    'K'=> '111010111',
    'L'=> '101110101',
    'M'=> '1110111',
    'N'=> '11101',
    'O'=> '11101110111',
    'P'=> '10111011101',
    'Q'=> '1110111010111',
    'R'=> '1011101',
    'S'=> '10101',
    'T'=> '111',
    'U'=> '1010111',
    'V'=> '101010111',
    'W'=> '101110111',
    'X'=> '11101010111',
    'Y'=> '1110101110111',
    'Z'=> '11101110101',
    '0'=> '1110111011101110111',
    '1'=> '10111011101110111',
    '2'=> '101011101110111',
    '3'=> '1010101110111',
    '4'=> '10101010111',
    '5'=> '101010101',
    '6'=> '11101010101',
    '7'=> '1110111010101',
    '8'=> '111011101110101',
    '9'=> '11101110111011101',
    '.'=> '10111010111010111',
    ','=> '1110111010101110111',
    '?'=> '101011101110101',
    "'"=> '1011101110111011101',
    '!'=> '1110101110101110111',
    '/'=> '1110101011101',
    '('=> '111010111011101',
    ')'=> '1110101110111010111',
    '&'=> '10111010101',
    ':'=> '11101110111010101',
    ';'=> '11101011101011101',
    '='=> '1110101010111',
    '+'=> '1011101011101',
    '-'=> '111010101010111',
    '_'=> '10101110111010111',
    '"'=> '101110101011101',
    '$'=> '10101011101010111',
    '@'=> '10111011101011101',
    ' '=> '0'
  }
  
  CHAR_SEP = '000'
  WORD_SEP = CHAR_SEP + @alpha[' '] + CHAR_SEP
end


if __FILE__ == $0
  m = Morse.encode("(?:.+)")
  puts Morse.decode(m)
end
