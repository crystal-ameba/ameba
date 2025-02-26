module Ameba::Rule::Lint
  # A rule that checks for whitespace around macro expressions.
  #
  # This is considered invalid:
  #
  # ```
  # {{foo}}
  # ```
  #
  # And it has to written as this instead:
  #
  # ```
  # {{ foo }}
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/WhitespaceAroundMacroExpression:
  #   Enabled: true
  # ```
  class WhitespaceAroundMacroExpression < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Reports missing spaces around macro expressions"
    end

    MSG = "Missing spaces around macro expression"

    def test(source, node : Crystal::MacroExpression)
      return unless node.output?
      return unless code = node_source(node, source.lines)
      return if code.starts_with?("{{ ") && code.ends_with?(" }}")

      issue_for node, MSG do |corrector|
        corrected_code =
          "{{ #{code[2...-2].strip} }}"

        corrector.replace(node, corrected_code)
      end
    end
  end
end
