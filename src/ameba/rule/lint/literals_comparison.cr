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

    # Edge-case: `{{ T == Nil }}`
    #
    # Current implementation just skips all macro contexts,
    # regardless of the free variable being present.
    #
    # Ideally we should only check whether either of the sides
    # is a free var
    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroExpression,
        Crystal::MacroIf,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(OP_NAMES)
      return unless (obj = node.obj) && (arg = node.args.first?)

      obj_is_literal, obj_is_static = literal_kind?(obj, include_paths: true)
      arg_is_literal, arg_is_static = literal_kind?(arg, include_paths: true)

      return unless obj_is_literal && arg_is_literal

      is_dynamic = !obj_is_static || !arg_is_static

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
