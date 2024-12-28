module Ameba::Rule::Typing
  # A rule that enforces that `Proc` literals have a return type.
  #
  # For example, these are considered valid:
  #
  # ```
  # greeter = ->(name : String) : String { "Hello #{name}" }
  # ```
  #
  # ```
  # task -> : Task { Task.new("execute this command") }
  # ```
  #
  # And these are invalid:
  #
  # ```
  # greeter = ->(name : String) { "Hello #{name}" }
  # ```
  #
  # ```
  # task -> { Task.new("execute this command") }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Typing/ProcReturnTypeRestriction:
  #   Enabled: false
  # ```
  class ProcLiteralReturnTypeRestriction < Base
    properties do
      description "Disallows Proc literals without return type restrictions"
      enabled false
    end

    MSG = "Proc literal should have a return type restriction"

    def test(source, node : Crystal::ProcLiteral)
      return if node.def.return_type

      issue_for node, MSG
    end
  end
end
