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

      node_code =
        node_source(node, source.lines)

      # `return(nil)`
      if node_code.try(&.includes?('('))
        issue_for exp, MSG
      else
        issue_for exp, MSG do |corrector|
          corrector.replace(node, node.to_s.sub(/\s*\(?nil\)?$/, ""))
        end
      end
    end
  end
end
