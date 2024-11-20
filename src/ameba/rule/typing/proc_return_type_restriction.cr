module Ameba::Rule::Typing
  # A rule that enforces that Proc literals have a return type.
  #
  # For example, these are considered valid:
  #
  # ```
  # my_proc = ->(arg : String) : String { a + "proc" }
  # ```
  #
  # ```
  # task -> : Task { Task.new("execute this command") }
  # ```
  #
  # And these are invalid:
  #
  # ```
  # my_proc = ->(arg : String) { a + "proc" }
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
  #   Enabled: true
  # ```
  class ProcReturnTypeRestriction < Base
    properties do
      description "Disallows proc literals without return type restrictions"
    end

    MSG = "Proc literals require a return type"

    def test(source, node : Crystal::ProcLiteral)
      return if node.def.return_type

      issue_for node, MSG
    end
  end
end
