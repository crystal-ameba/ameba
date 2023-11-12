module Ameba::Rule::Lint
  # This rule is used to identify usages of `not_nil!` calls.
  #
  # For example, this is considered a code smell:
  #
  # ```
  # names = %w[Alice Bob]
  # alice = names.find { |name| name == "Alice" }.not_nil!
  # ```
  #
  # And can be written as this:
  #
  # ```
  # names = %w[Alice Bob]
  # alice = names.find { |name| name == "Alice" }
  #
  # if alice
  #   # ...
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/NotNil:
  #   Enabled: true
  # ```
  class NotNil < Base
    properties do
      description "Identifies usage of `not_nil!` calls"
    end

    MSG = "Avoid using `not_nil!`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "not_nil!"
      return unless node.obj && node.args.empty?

      issue_for node, MSG, prefer_name_location: true
    end
  end
end
