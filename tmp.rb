def calc(expression)
  terms = split_into_terms(expression)
  do_calc(terms).to_f
end

def do_calc(terms)
  return terms.first if terms.size == 1
  i_paren = terms.index { |term| term == '(' || term == '-(' }
  if i_paren
    i_paren_end = index_of_paren_close(terms, i_paren)
    value = do_calc(terms[i_paren + 1, i_paren_end - i_paren - 1])
    value = (value.to_f * -1).to_s if terms[i_paren] == '-('
    terms[i_paren, i_paren_end - i_paren + 1] = value
    do_calc(terms)
  else
    i_op = terms.index { |term| term == '*' || term == '/' } \
        || terms.index { |term| term == '+' || term == '-' }
    num1 = terms[i_op - 1].to_f
    num2 = terms[i_op + 1].to_f
    value = case terms[i_op]
    when '*'
      num1 * num2
    when '/'
      num1 / num2
    when '+'
      num1 + num2
    when '-'
      num1 - num2
    end
    terms[i_op - 1, 3] = value.to_s
    do_calc(terms)
  end
end

def index_of_paren_close(terms, i_paren)
  depth = 0
  (i_paren + 1 ... terms.size).each do |index|
    term = terms[index]
    if term == '(' || term == '-('
      depth += 1
    elsif term == ')'
      return index if depth.zero?
      depth -= 1
    end
  end
end

def split_into_terms(expression)
  exp = expression.dup
  terms = []
  expecting_number = true
  while !exp.empty? do
    terms << shift_term_from(exp, expecting_number)
    expecting_number = %w[* / + - ( -(].include?(terms.last)
  end
  terms
end

def shift_term_from(expression, expecting_number)
  expression.strip!
  if %w[* / + ( )].include?(expression[0]) || (expression[0] == '-' && !expecting_number)
    expression.slice!(0)
  elsif expression[0, 2] == '-(' && expecting_number
    expression.slice!(0, 2)
  else
    expression.slice!(/\A-?[\d.]+/)
  end
end


# Expected: '12* 123/-(-5 + 2)' to be 492 but got 3.0 - Expected: 492, instead got: 3.0

tests = [
  ['(1 - 2) + -(-(-(-4)))', 3],
=begin
  ['1-1', 0],
  ['1 -1', 0],
  ['1- 1', 0],
  ['1 - 1', 0],
  ['1- -1', 2],
  ['1 - -1', 2],
  ['6 + -(4)', 2],
  ['6 + -( -4)', 10],

  ['12* 123/-(-5 + 2)', 492],

  ['1+1', 2],
  ['1 - 1', 0],
  ['1* 1', 1],
  ['1 /1', 1],
  ['-123', -123],
  ['123', 123],
  ['2 /2+3 * 4.75- -6', 21.25],
  ['12* 123', 1476],
  ['2 / (2 + 3) * 4.33 - -6', 7.732],
  ['(2 / (2 + 0.5) * 4) - -6', 9.2],
=end
]

tests.each do |expression, result|
  p calc(expression)
end
