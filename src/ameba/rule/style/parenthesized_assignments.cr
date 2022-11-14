module Ameba::Rule::Style
  # A rule that disallows assignments without parens in control expressions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if foo = @foo
  #   do_something
  # end
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # if (foo = @foo)
  #   do_something
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/ParenthesizedAssignments:
  #   Enabled: true
  # ```
  class ParenthesizedAssignments < Base
    properties do
      enabled false
      description "Disallows assignments without parens in control expressions"
    end

    MSG = "Missing parentheses around assignment"

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      return unless (cond = node.cond).is_a?(Crystal::Assign)

      issue_for cond, MSG do |corrector|
        corrector.insert_before(cond, '(')
        corrector.insert_after(cond, ')')
      end
    end
  end
end
