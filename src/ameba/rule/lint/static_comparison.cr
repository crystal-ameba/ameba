module Ameba::Rule::Lint
  # This rule is used to identify static comparisons -
  # the ones that will always have the same result.
  #
  # For example, this will be always false:
  #
  # ```
  # "foo" == 42
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/StaticComparison:
  #   Enabled: true
  # ```
  class StaticComparison < Base
    include AST::Util

    properties do
      description "Identifies static comparisons"
    end

    OP_NAMES = %w(== !=)
    MSG      = "Comparison always evaluates to %s"

    PRIMITIVES = {
      Crystal::NilLiteral,
      Crystal::BoolLiteral,
      Crystal::NumberLiteral,
      Crystal::CharLiteral,
      Crystal::StringLiteral,
      Crystal::SymbolLiteral,
      Crystal::RangeLiteral,
      Crystal::RegexLiteral,
      Crystal::TupleLiteral,
      Crystal::NamedTupleLiteral,
      Crystal::ArrayLiteral,
      Crystal::HashLiteral,
      Crystal::ProcLiteral,
    }

    def test(source, node : Crystal::Call)
      return unless node.name.in?(OP_NAMES)
      return unless (obj = node.obj) && (arg = node.args.first?)
      return unless obj.class.in?(PRIMITIVES) && arg.class.in?(PRIMITIVES)

      case node.name
      when "=="
        what = (obj.to_s == arg.to_s).to_s
      when "!="
        what = (obj.to_s != arg.to_s).to_s
      end

      issue_for node, MSG % what
    end
  end
end
