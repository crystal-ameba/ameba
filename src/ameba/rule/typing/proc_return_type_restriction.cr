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
      description "Recommends that proc literals have a return type restriction"
    end

    MSG = "Proc literals should have a return type"

    def test(source, node : Crystal::ProcLiteral)
      return if node.def.return_type

      issue_for node, MSG
    end
  end
end
