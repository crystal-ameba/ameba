module Ameba::Rule::Style
  # Encourages the use of `Array(T).new` syntax for creating an array over `[] of T`
  #
  # ```
  # # bad
  # [] of Int32 | String?
  #
  # # good
  # Array(Int32 | String?).new
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/ArrayLiteralSyntax:
  #   Enabled: false
  # ```
  class ArrayLiteralSyntax < Base
    properties do
      since_version "1.7.0"
      enabled false
      description "Encourages the use of `Array(T).new` over `[] of T`"
    end

    MSG = "Use `Array(%s).new` for creating an empty array"

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::ArrayLiteral)
      return unless node.elements.empty? && (array_type = node.of)

      issue_for node, MSG % array_type do |corrector|
        corrector.replace(node, "Array(#{array_type}).new")
      end
    end
  end
end
