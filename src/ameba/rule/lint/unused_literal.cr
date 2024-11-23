module Ameba::Rule::Lint
  # A rule that disallows unused literal values (strings, symbols, integers, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # 1234_f32
  #
  # "hello world"
  #
  # if check?
  #   true
  # else
  #   false
  # end
  #
  # def method
  #   if guard?
  #     false
  #   end
  #
  #   true
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = 1234_f32
  #
  # def method
  #   if guard?
  #     false
  #   else
  #     true
  #   end
  # end
  #
  # my_proc = -> : Bool { true }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedLiteral:
  #   Enabled: true
  # ```
  class UnusedLiteral < Base
    properties do
      description "Disallows unused literal values"
    end

    MSG = "Literal value is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(
      source,
      node : Crystal::BoolLiteral | Crystal::CharLiteral | Crystal::HashLiteral |
             Crystal::ProcLiteral | Crystal::ArrayLiteral | Crystal::RangeLiteral |
             Crystal::TupleLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::NamedTupleLiteral,
      last_is_used : Bool
    ) : Bool
      if !last_is_used
        issue_for node, MSG
      end

      true
    end
  end
end
