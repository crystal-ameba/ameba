module Ameba::Rule
  # A rule that disallows `rand(0)` and `rand(1)` calls.
  # Such calls always return `0`.
  #
  # For example:
  #
  # ```
  # rand(1)
  # ```
  #
  # Should be written as:
  #
  # ```
  # rand
  # # or
  # rand(2)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # RandZero:
  #   Enabled: true
  # ```
  #
  struct RandZero < Base
    properties do
      description "Disallows rand zero calls"
    end

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "rand" &&
                    node.args.size == 1 &&
                    (arg = node.args.first) &&
                    (arg.is_a? Crystal::NumberLiteral) &&
                    (value = arg.value) &&
                    (value == "0" || value == "1")

      source.error self, node.location, "#{node} always returns 0"
    end
  end
end
