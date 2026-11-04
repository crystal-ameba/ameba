module Ameba::Rule::Style
  # A rule that disallows control expressions (`return`, `break` and `next`)
  # with `nil` argument.
  #
  # This is considered invalid:
  #
  # ```
  # def greeting(name)
  #   return nil unless name
  #
  #   "Hello, #{name}"
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # def greeting(name)
  #   return unless name
  #
  #   "Hello, #{name}"
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/RedundantNilInControlExpression:
  #   Enabled: true
  # ```
  class RedundantNilInControlExpression < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows control expressions with `nil` argument"
    end

    MSG = "Redundant `nil` detected"

    def test(source, node : Crystal::ControlExpression)
      return unless (exp = node.exp).is_a?(Crystal::NilLiteral)

      location = node.location
      end_location = control_exp_end_location(node, source.lines)

      if location && end_location && control_exp_replaceable?(node, source.lines)
        # Keep just the keyword (`return`, `next`, `break`)
        keyword = (node_source(node, source.lines) || node.to_s)[/\A\w+/]

        issue_for(exp, MSG) do |corrector|
          corrector.replace(location, end_location, keyword)
        end
      else
        issue_for(exp, MSG)
      end
    end
  end
end
