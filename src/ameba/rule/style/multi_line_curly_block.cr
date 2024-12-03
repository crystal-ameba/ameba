module Ameba::Rule::Style
  # A rule that disallows multi-line blocks that use curly brackets instead of
  # `do`...`end`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # incr_stack {
  #   node.body.accept(self)
  # }
  # ```
  #
  # And should be rewritten to the following:
  #
  # ```
  # incr_stack do
  #   node.body.accept(self)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/MultiLineCurlyBlock:
  #   Enabled: true
  # ```
  class MultiLineCurlyBlock < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows multi-line blocks using curly block syntax"
    end

    MSG = "Use `do`...`end` instead of curly brackets for multi-line blocks"

    def test(source, node : Crystal::Block)
      return unless start_location = node.location
      return unless end_location = node.end_location
      return if start_location.line_number == end_location.line_number
      return unless source.code[source.pos(start_location)]? == '{'

      issue_for node, MSG
    end
  end
end
