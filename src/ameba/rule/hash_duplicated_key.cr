module Ameba::Rule
  # A rule that disallows duplicated keys in hash literals.
  #
  # This is considered invalid:
  #
  # ```
  # h = {"foo" => 1, "bar" => 2, "foo" => 3}
  # ```
  #
  # And it has to written as this instead:
  #
  # ```
  # h = {"foo" => 1, "bar" => 2}
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # HashDuplicatedKey:
  #   Enabled: true
  # ```
  #
  struct HashDuplicatedKey < Base
    properties do
      description = "Disallows duplicated keys in hash literals"
    end

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::HashLiteral)
      return unless duplicated_keys?(node.entries)

      source.error self, node.location, "Duplicated keys in hash literal."
    end

    private def duplicated_keys?(entries)
      entries.map(&.key)
             .group_by(&.itself)
             .any? { |_, v| v.size > 1 }
    end
  end
end
