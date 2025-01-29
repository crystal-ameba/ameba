module Ameba::Rule::Typing
  # A rule that enforces that `Proc` literals have a return type.
  #
  # For example, these are considered invalid:
  #
  # ```
  # greeter = ->(name : String) { "Hello #{name}" }
  # ```
  #
  # ```
  # task = -> { Task.new("execute this command") }
  # ```
  #
  # And these are valid:
  #
  # ```
  # greeter = ->(name : String) : String { "Hello #{name}" }
  # ```
  #
  # ```
  # task = -> : Task { Task.new("execute this command") }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Typing/ProcLiteralReturnTypeRestriction:
  #   Enabled: true
  # ```
  class ProcLiteralReturnTypeRestriction < Base
    properties do
      since_version "1.7.0"
      description "Disallows proc literals without return type restriction"
      enabled false
    end

    MSG = "Proc literal should have a return type restriction"

    def test(source, node : Crystal::ProcLiteral)
      issue_for node, MSG unless node.def.return_type
    end
  end
end
