require 'dentaku/rules'
require 'dentaku/binary_operation'

module Dentaku
  class Evaluator
    def evaluate(tokens)
      evaluate_token_stream(tokens).value
    end

    def evaluate_token_stream(tokens)
      while tokens.length > 1
        matched, tokens = match_rule_pattern(tokens)
        raise "no rule matched {{#{ inspect_tokens(tokens) }}}" unless matched
      end

      tokens << Token.new(:numeric, 0) if tokens.empty?

      tokens.first
    end

    def inspect_tokens(tokens)
      tokens.map { |t| t.to_s }.join(' ')
    end

    def match_rule_pattern(tokens)
      matched = false
      Rules.each do |pattern, evaluator|
        pos, match = find_rule_match(pattern, tokens)

        if pos
          tokens = evaluate_step(tokens, pos, match.length, evaluator)
          matched = true
          break
        end
      end

      [matched, tokens]
    end

    def find_rule_match(pattern, token_stream)
      position = 0

      while position <= token_stream.length
        matches = []
        matched = true

        pattern.each do |matcher|
          _matched, match = matcher.match(token_stream, position + matches.length)
          matched &&= _matched
          break unless matched
          matches += match
        end

        return position, matches if matched
        return if pattern.first.caret?
        position += 1
      end

      nil
    end

    def evaluate_step(token_stream, start, length, evaluator)
      substream = token_stream.slice!(start, length)

      if self.respond_to?(evaluator)
        token_stream.insert start, *self.send(evaluator, *substream)
      else
        result = user_defined_function(evaluator, substream)
        token_stream.insert start, result
      end
    end

    def user_defined_function(evaluator, tokens)
      function = Rules.func(evaluator)
      raise "unknown function '#{ evaluator }'" unless function

      arguments = extract_arguments_from_function_call(tokens).map { |t| t.value }
      return_value = function.body.call(*arguments)
      Token.new(function.type, return_value)
    end

    def extract_arguments_from_function_call(tokens)
      _close = tokens.pop
      _function_name, _open, *args_and_commas = tokens
      args_and_commas.reject { |token| token.is?(:grouping) }
    end

    def evaluate_group(*args)
      evaluate_token_stream(args[1..-2])
    end

    def apply(lvalue, operator, rvalue)
      operation = BinaryOperation.new(lvalue.value, rvalue.value)
      raise "unknown operation #{ operator.value }" unless operation.respond_to?(operator.value)
      Token.new(*operation.send(operator.value))
    end

    def negate(_, token)
      Token.new(token.category, token.value * -1)
    end

    def pow_negate(base, _, __, exp)
      Token.new(base.category, base.value ** (exp.value * -1))
    end

    def mul_negate(val1, _, __, val2)
      Token.new(val1.category, val1.value * val2.value * -1)
    end

    def percentage(token, _)
      Token.new(token.category, token.value / 100.0)
    end

    def expand_range(left, oper1, middle, oper2, right)
      [left, oper1, middle, Token.new(:combinator, :and), middle, oper2, right]
    end

    def if(*args)
      _if, _open, condition, _, true_value, _, false_value, _close = args

      if condition.value
        true_value
      else
        false_value
      end
    end

    def round(*args)
      _ = args.pop
      _, _, *tokens = args

      temp = []
      chunk = []

      tokens.each do |t|
        if t.category == :grouping
          temp << chunk
          chunk = []
        else
          chunk << t
        end
      end
      temp << chunk

      input_tokens, places_tokens = temp.reject{|ar| ar.empty?}

      input_value  = evaluate_token_stream(input_tokens).value
      places       = places_tokens ? evaluate_token_stream(places_tokens).value : 0

      # round function. tested for positive values and places
      to_ceil = (input_value*(10**places))
      value = (to_ceil - to_ceil.to_i) >= 0.5 ? (to_ceil.ceil)/(10.0**places) : (to_ceil.to_i)/(10.0**places)

      Token.new(:numeric, value)
    end

    def round_int(*args)
      _ = args.pop
      function, _, *tokens = args

      value = evaluate_token_stream(tokens).value
      rounded = if function.value == :roundup
        value.ceil
      else
        value.floor
      end

      Token.new(:numeric, rounded)
    end

    def not(*args)
      Token.new(:logical, ! evaluate_token_stream(args[2..-2]).value)
    end
  end
end
