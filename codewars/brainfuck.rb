class Brainfuck
  # >: increment the data pointer (to point to the next cell to the right).
  # <: decrement the data pointer (to point to the next cell to the left).
  # +: increment (increase by one, truncate overflow: 255 + 1 = 0) the byte at the data pointer.
  # -: decrement (decrease by one, treat as unsigned byte: 0 - 1 = 255 ) the byte at the data pointer.
  # .: output the byte at the data pointer.
  # ,: accept one byte of input, storing its value in the byte at the data pointer.
  # [: if the byte at the data pointer is zero, then instead of moving the instruction pointer
  #    forward to the next command, jump it forward to the command after the matching ] command.
  # ]: if the byte at the data pointer is nonzero, then instead of moving the instruction pointer
  #    forward to the next command, jump it back to the command after the matching [ command.

  def initialize(code, input, debug: false)
    @code = code
    @input = input

    @cursor_code = 0
    @cursor_input = 0
    @paren_indexes = []

    @byte_array = [0]
    @pointer = 0
    @output_buffer = []

    @debug = debug
  end

  def execute
    begin
      while execute_command
        print "#{@byte_array}(#{@pointer}) " if @debug
      end
      @output_buffer.join
    rescue => e
      STDERR.puts "While executing '#{@code[@cursor_code]}' at #{@cursor_code}, #{@byte_array.inspect}(<- #{@pointer})"
      raise e
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
        @byte_array[@pointer] = 0 if @byte_array[@pointer] > 255
      when '-'
        @byte_array[@pointer] -= 1
        @byte_array[@pointer] = 255 if @byte_array[@pointer] < 0
      when '.'
        @output_buffer << @byte_array[@pointer].chr
      when ','
        @byte_array[@pointer] = @input[@cursor_input].ord
        @cursor_input += 1
      when '['
        if @byte_array[@pointer].zero?
          jump_to_close_paren
        else
          @paren_indexes.push(@cursor_code)
        end
      when ']'
        open_paren_index = @paren_indexes.pop
        if @byte_array[@pointer] > 0
          @cursor_code = open_paren_index
          @paren_indexes.push(@cursor_code)
        end
      end
      @cursor_code += 1
      true
    end

    def jump_to_close_paren
      depth = 0
      while true do
        @cursor_code += 1
        command = @code[@cursor_code]
        case command
        when '['
          depth += 1
        when ']'
          break if depth == 0
          depth -= 1
        when nil
          raise SyntaxError, "Expecting ']'"
        end
      end
    end
end

def brain_luck(code, input)
  Brainfuck.new(code, input).execute
end


require_relative 'test'

if __FILE__ == $0
  # Echo until byte(255) encountered
  Test.assert_equals(
    brain_luck(',+[-.,+]', 'Codewars' + 255.chr), 
    'Codewars'
  )

  # Echo until byte(0) encountered
  Test.assert_equals(
    brain_luck(',[.[-],]', 'Codewars' + 0.chr), 
    'Codewars'
  );

  # Two numbers multiplier
  Test.assert_equals(
    brain_luck(',>,<[>[->+>+<<]>>[-<<+>>]<<<-]>>.', 8.chr + 9.chr), 
    72.chr
  )

  # Hellow, world!
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
  Test.assert_equals(
    brain_luck(code, input), 
    "Hello, world!"
  )

  #code = %w[,>,< [ > [ >+ >+ << -] >> [- << + >>] <<< -] >>].join
  #input = '45'
end
