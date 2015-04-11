require "bigdecimal"
require "dentaku/calculator"
require "dentaku/version"


Float::INFINITY = 1.0/0.0

module Dentaku
  def self.evaluate(expression, data={})
    calculator.evaluate(expression, data)
  end

  private

  def self.calculator
    @calculator ||= Dentaku::Calculator.new
  end
end

def Dentaku(expression, data={})
  Dentaku.evaluate(expression, data)
end
