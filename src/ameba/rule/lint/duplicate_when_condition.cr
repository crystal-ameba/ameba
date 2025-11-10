module Ameba::Rule::Lint
  # Reports repeated conditions used in case `when` expressions.
  #
  # This is considered invalid:
  #
  # ```
  # case x
  # when .nil?
  #   do_something
  # when .nil?
  #   do_something_else
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # case x
  # when .nil?
  #   do_something
  # when Symbol
  #   do_something_else
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DuplicateWhenCondition:
  #   Enabled: true
  # ```
  class DuplicateWhenCondition < Base
    properties do
      since_version "1.7.0"
      description "Reports repeated conditions used in case `when` expressions"
    end

    MSG = "Duplicate `when` condition detected"

    def test(source, node : Crystal::Case | Crystal::Select)
      found_conditions = Set(String).new

      node.whens.each &.conds.each do |cond|
        next if found_conditions.add?(cond.to_s)

        issue_for cond, MSG
      end
    end
  end
end
