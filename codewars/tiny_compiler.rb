class Compiler

  def compile(program)
    pass3(pass2(pass1(program)))
  end

  def tokenize(program)
    # Turn a program string into an array of tokens.  Each token
    # is either '[', ']', '(', ')', '+', '-', '*', '/', a variable
    # name or a number (as a string)
    program.scan(%r'[-+*/()\[\]]|[A-Za-z]+|\d+').map { |token| /^\d+$/.match(token) ? token.to_i : token }
  end

  def pass1(program)
    # Returns an un-optimized AST
    tokens = tokenize(program)
    function = Function.new(tokens)
    h = function.parse
    JSON.dump(h)
  end

  def pass2(ast)
    # Returns an AST with constant expressions reduced
  end

  def pass3(ast)
    # Returns assembly instructions
  end

  class Function

    ARGLIST_START = '['
    ARGLIST_END   = ']'

    def initialize(tokens)
      args, exp_tokens = split_tokens(tokens)
      arg_list = ArgList.new(args)
      @expression = Expression.new(exp_tokens, arg_list)
    end

    def parse
      @expression.parse
    end

    private

      def split_tokens(tokens)
        i_start = tokens.index(ARGLIST_START) + 1
        i_delim = tokens.index(ARGLIST_END)
        args = tokens[i_start ... i_delim]
        expressions = tokens[i_delim + 1 .. -1]
        [args, expressions]
      end

    class ArgList

      def initialize(args)
        @arg_number = args.map.with_index { |name, number| [name, number] }.to_h
      end

      def number_for(name)
        @arg_number[name]
      end
    end

    class Expression

      def initialize(tokens, arg_list)
        @tokens = tokens.map { |value| Token.new(value) }
        Token.arg_list = arg_list
      end

      def parse
        stack = []
        while !@tokens.empty? do

          if false
            puts stack.map(&:to_s).join(',')
            puts @tokens.join(',')
            puts
          end

          token = @tokens.shift
          if token.operand? && stack[-1]&.high_operator?
            stack.push(token)
            operate_last_in(stack)
          elsif token.low_operator?
            operate_last_in(stack)
            stack.push(token)
          elsif token.right_paren?
            while !stack[-2].left_paren? do
              operate_last_in(stack)
            end
            t = stack.pop
            stack.pop
            stack.push(t)
          else
            stack.push(token)
          end
        end
        operate_last_in(stack)
        stack.pop.repr
      end

      private

        def operate_last_in(stack)
          return unless stack[-2]&.operator?
          operand1 = stack.pop
          operator = stack.pop
          operand0 = stack.pop
          operation = Operation.new(operator, operand0, operand1)
          stack.push(operation)
        end

      class Operation

        def initialize(operator, operand0, operand1)
          @operator = operator
          @operand0 = operand0.repr
          @operand1 = operand1.repr
        end

        def repr
          {op: @operator, 'a': @operand0, 'b': @operand1}
        end

        def to_s
          repr.merge(op: @operator.to_s)
        end
      end

      class Token

        def self.arg_list=(value)
          @@arg_list = value
        end

        def initialize(value)
          @value = value
        end

        def number?
          @value.is_a?(Numeric)
        end

        def variable?
          @value =~ /\A[A-Za-z]\z/
        end

        def operand?
          number? || variable?
        end

        def high_operator?
          %w[* /].include?(@value)
        end

        def low_operator?
          %w[+ -].include?(@value)
        end

        def operator?
          high_operator? || low_operator?
        end

        def left_paren?
          @value == '('
        end

        def right_paren?
          @value == ')'
        end

        def repr
          if number?
            {op: 'imm', 'n': @value}
          elsif variable?
            {op: 'arg', 'n': @@arg_list.number_for(@value)}
          end
        end

        def to_s
          @value.to_s
        end
      end
    end
  end

  private

    def variable?(token)
      token =~ /\A[A-Za-z]+\z/
    end
end


require 'pry'

if __FILE__ == $0
  require 'json'
  require_relative 'test'

  c = Compiler.new

  #puts JSON.pretty_generate(JSON.parse(c.pass1("[a b] ((a + b) * 5) / (a - b)")))
  #exit


  expected_in_json = <<-JSON
    { 'op': '+', 'a': { 'op': 'arg', 'n': 0 },
                 'b': { 'op': '*', 'a': { 'op': 'imm', 'n': 2 },
                                   'b': { 'op': 'imm', 'n': 5 } } }
  JSON
  expected = JSON.parse(expected_in_json.gsub("'", '"'))
  actual = JSON.parse(c.pass1('[ x ] x + 2*5'))
  Test.assert_equals(actual, expected)

  expected_in_json = <<-JSON
    { 'op': '/', 'a': { 'op': '+', 'a': { 'op': 'arg', 'n': 0 },
                                   'b': { 'op': 'arg', 'n': 1 } },
                 'b': { 'op': 'imm', 'n': 2 } }
  JSON
  expected = JSON.parse(expected_in_json.gsub("'", '"'))
  actual = JSON.parse(c.pass1('[ x y ] ( x + y ) / 2'))
  Test.assert_equals(actual, expected)

  expected_in_json = <<-JSON
    { 'op': '+', 'a': { 'op': '*', 'a': { 'op': 'arg', 'n': 0 },
                                   'b': { 'op': 'arg', 'n': 0 } },
                 'b': { 'op': '*', 'a': { 'op': 'arg', 'n': 1 },
                                   'b': { 'op': 'arg', 'n': 1 } } }
  JSON
  expected = JSON.parse(expected_in_json.gsub("'", '"'))
  actual = JSON.parse(c.pass1('[ a b ] a*a + b*b'))
  Test.assert_equals(actual, expected)
end
