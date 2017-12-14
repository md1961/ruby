class Brainfuck

  # >： ポインターをインクリメント（配列内の次の要素を指す）
  # <： ポインターをデクリメント（配列内の前の要素を指す）
  # +： ポインターが指す位置のデータをインクリメント
  # -： ポインターが指す位置のデータをデクリメント
  # .： ポインターが指す位置のデータを出力する
  # ,： 1バイトのデータの入力を受け取り、ポインターが指す位置に保存
  # [： ポインターが指す位置のデータが0であれば、対応する「]」の後までジャンプ
  # ]： 対応する「[」にジャンプ

  def initialize(code, input, debug: false)
    @code = code
    @input = input
    @debug = debug
    @cursor_code = 0
    @cursor_input = 0

    @byte_array = [0]
    @pointer = 0
  end

  def execute
    while execute_command
      print "#{@byte_array} " if @debug
    end
  end

  private

    def execute_command
      command = @code[@cursor_code]
      return false unless command

      case command
      when '>'
        @pointer += 1
        @byte_array[@pointer] ||= 0
      when '<'
        @pointer -= 1
      when '+'
        @byte_array[@pointer] += 1
      when '-'
        @byte_array[@pointer] -= 1
      when '.'
        print @byte_array[@pointer].chr
      when ','
        @byte_array[@pointer] = @input[@cursor_input]
        @cursor_input += 1
      when '['
        if @byte_array[@pointer].zero?
          @cursor_code += @code[@cursor_code, @code.length].split('').index { |c| c == ']' }
          raise SyntaxError, "Expecting ']'" unless @cursor_code
        end
      when ']'
        @cursor_code = @code[0, @cursor_code].split('').rindex { |c| c == '[' }
        @cursor_code -= 1
      end
      @cursor_code += 1
      true
    end
end


if __FILE__ == $0
  code = %w[
    ++++++++[>+++++++++<-]>.
    <+++[>++++++++++<-]>-.
    +++++++..
    +++.
    <++++++++[>--------<-]>---.
    ------------.
    <++++++++[>+++++++++++<-]>-.
    --------.
    +++.
    ------.
    --------.
    <++++++++[>--------<-]>---.
  ].join
  input = ''
  Brainfuck.new(code, input).execute
  puts
end
