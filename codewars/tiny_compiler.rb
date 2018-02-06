class Compiler

  def compile(program)
    pass3(pass2(pass1(program)))
  end

  # Turn a program string into an array of tokens.  Each token
  # is either '[', ']', '(', ')', '+', '-', '*', '/', a variable
  # name or a number (as a string)
  def tokenize(program)
    program.scan(%r'[-+*/()\[\]]|[A-Za-z]+|\d+').map { |token| /^\d+$/.match(token) ? token.to_i : token }
  end

  # Returns an un-optimized AST
  def pass1(program)
    tokens = tokenize(program)
    function = Function.new(tokens)
    h_ast = function.parse
    JSON.dump(h_ast)
  end

  # Returns an AST with constant expressions reduced
  def pass2(ast)
    h_ast = JSON.parse(ast)
    reduce_constant_expression(h_ast)
    JSON.dump(h_ast)
  end

  # Returns assembly instructions
  def pass3(ast)
    h_ast = JSON.parse(ast)
    @directives = []
    assembly_parse(h_ast)
  end

  private

    def operator?(h_ast)
      h_ast && %w[+ - * /].include?(h_ast['op'])
    end

    def immediate?(h_ast)
      h_ast && h_ast['op'] == 'imm'
    end

    def reduce_constant_expression(h_ast)
      reduce_constant_expression(h_ast['a']) if h_ast.key?('a')
      reduce_constant_expression(h_ast['b']) if h_ast.key?('b')
      if operator?(h_ast) && immediate?(h_ast['a']) && immediate?(h_ast['b'])
        a = h_ast['a']['n']
        b = h_ast['b']['n']
        h_ast['n'] = \
          case h_ast['op']
          when '+'
            a + b
          when '-'
            a - b
          when '*'
            a * b
          when '/'
            a / b
          end
        h_ast['op'] = 'imm'
        h_ast.delete('a')
        h_ast.delete('b')
      end
    end

    ASSEMBLY_OP_LOOKUP = {'+' => 'AD', '-' => 'SU', '*' => 'MU', '/' => 'DI'}

    def assembly_parse(h_ast)
      if operator?(h_ast)
        if operator?(h_ast['a'])
          assembly_parse(h_ast['a'])
          @directives << 'PU'
          assembly_parse(h_ast['b'])
          @directives << 'SW'
          @directives << 'PO'
        else
          assembly_parse(h_ast['b'])
          @directives << 'SW'
          assembly_parse(h_ast['a'])
        end
        @directives << ASSEMBLY_OP_LOOKUP[h_ast['op']]
      elsif immediate?(h_ast)
        @directives << "IM #{h_ast['n']}"
      else
        @directives << "AR #{h_ast['n']}"
      end
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
end


def simulate(instructions, argv)
  r0, r1 = 0, 0
  stack = []
  instructions.each do |ins|
    ins, n = ins.split
    n = n&.to_i
    case ins
    when 'IM'
      r0 = n
    when 'AR'
      r0 = argv[n]
    when 'SW'
      r0, r1 = r1, r0
    when 'PU'
      stack.push(r0)
    when 'PO'
      r0 = stack.pop
    when 'AD'
      r0 += r1
    when 'SU'
      r0 -= r1
    when 'MU'
      r0 *= r1
    when 'DI'
      r0 /= r1
    end
  end
  r0
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

  ast = <<-JSON
    { 'op': '+', 'a': { 'op': 'arg', 'n': 0 },
                 'b': { 'op': '*', 'a': { 'op': 'imm', 'n': 2 },
                                   'b': { 'op': 'imm', 'n': 5 } } }
  JSON
  expected_in_json = <<-JSON
    { 'op': '+', 'a': { 'op': 'arg', 'n': 0 },
                 'b': { 'op': 'imm', 'n': 10 } }
  JSON
  expected = JSON.parse(expected_in_json.gsub("'", '"'))
  actual = JSON.parse(c.pass2(ast.gsub("'", '"')))
  Test.assert_equals(actual, expected)

  ast = <<-JSON
    { 'op': '/', 'a': { 'op': 'imm', 'n': 12 },
                 'b': { 'op': '-', 'a': { 'op': 'imm', 'n': 2 },
                                   'b': { 'op': 'imm', 'n': 5 } } }
  JSON
  expected_in_json = <<-JSON
    { 'op': 'imm', 'n': -4 }
  JSON
  expected = JSON.parse(expected_in_json.gsub("'", '"'))
  actual = JSON.parse(c.pass2(ast.gsub("'", '"')))
  Test.assert_equals(actual, expected)

  ast = <<-JSON
    { 'op': '+', 'a': { 'op': 'arg', 'n': 0 },
                 'b': { 'op': 'imm', 'n': 10 } }
  JSON
  expected = [ "IM 10", "SW", "AR 0", "AD" ]
  actual = c.pass3(ast.gsub("'", '"'))
  Test.assert_equals(actual, expected)

  program = '[x] x + 2 * 5'
  expected = [ "IM 10", "SW", "AR 0", "AD" ]
  actual = c.compile(program)
  Test.assert_equals(actual, expected)

  asm = c.compile('[ a b ] a*a + b*b')
  p asm
  puts simulate(asm, [3, 5])
end
