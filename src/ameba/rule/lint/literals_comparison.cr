module Ameba::Rule::Lint
  # This rule is used to identify comparisons between two literals.
  #
  # They usually have the same result - except for non-primitive
  # types like containers, range or regex.
  #
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
  # Lint/LiteralsComparison:
  #   Enabled: true
  # ```
  class LiteralsComparison < Base
    include AST::Util

    properties do
      description "Identifies comparisons between literals"
    end

    OP_NAMES = %w(=== == !=)

    MSG        = "Comparison always evaluates to %s"
    MSG_LIKELY = "Comparison most likely evaluates to %s"

    PRIMITIVE_LITERAL_TYPES = {
      Crystal::NilLiteral,
      Crystal::BoolLiteral,
      Crystal::NumberLiteral,
      Crystal::CharLiteral,
      Crystal::StringLiteral,
      Crystal::SymbolLiteral,
      Crystal::ProcLiteral,
      Crystal::Path,
    }

    DYNAMIC_LITERAL_TYPES = {
      Crystal::RangeLiteral,
      Crystal::RegexLiteral,
      Crystal::TupleLiteral,
      Crystal::NamedTupleLiteral,
      Crystal::ArrayLiteral,
      Crystal::HashLiteral,
    }

    LITERAL_TYPES =
      PRIMITIVE_LITERAL_TYPES + DYNAMIC_LITERAL_TYPES

    def test(source, node : Crystal::Call)
      return unless node.name.in?(OP_NAMES)
      return unless (obj = node.obj) && (arg = node.args.first?)

      return unless obj.class.in?(LITERAL_TYPES) &&
                    arg.class.in?(LITERAL_TYPES)

      is_dynamic = obj.class.in?(DYNAMIC_LITERAL_TYPES) ||
                   arg.class.in?(DYNAMIC_LITERAL_TYPES)

      what =
        case node.name
        when "===" then "the same"
        when "=="  then (obj.to_s == arg.to_s).to_s
        when "!="  then (obj.to_s != arg.to_s).to_s
        end

      issue_for node, (is_dynamic ? MSG_LIKELY : MSG) % what
    end
  end
end
