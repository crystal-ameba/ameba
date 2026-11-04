module Ameba::Rule::Style
  # Encourages the use of `Hash(K, V).new` syntax for creating a hash over `{} of K => V`.
  #
  # Favour this:
  #
  # ```
  # Hash(Int32, String?).new
  # ```
  #
  # Over this:
  #
  # ```
  # {} of Int32 => String?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/HashLiteralSyntax:
  #   Enabled: true
  # ```
  class HashLiteralSyntax < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      enabled false
      description "Encourages the use of `Hash(K, V).new` over `{} of K => V`"
    end

    MSG = "Use `Hash(%s, %s).new` for creating an empty hash"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::HashLiteral)
      return unless node.entries.empty? && (hash_type = node.of)

      # `{} of Foo => (Bar ->)`: the node ends before the closing parenthesis
      unless balanced_parentheses?(node, source.lines)
        return issue_for(node, MSG % {hash_type.key, hash_type.value})
      end

      issue_for(node, MSG % {hash_type.key, hash_type.value}) do |corrector|
        corrector.replace(node, "Hash(#{hash_type.key}, #{hash_type.value}).new")
      end
    end
  end
end
