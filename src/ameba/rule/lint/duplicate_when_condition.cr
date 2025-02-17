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

    def test(source, node : Crystal::Case)
      node.whens.each_with_object(Set(String).new) do |when_node, processed_conditions|
        when_node.conds.each do |cond|
          cond_s = cond.to_s
          if processed_conditions.includes?(cond_s)
            issue_for cond, MSG
          else
            processed_conditions << cond_s
          end
        end
      end
    end
  end
end
