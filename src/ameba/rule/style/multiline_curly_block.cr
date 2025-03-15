module Ameba::Rule::Style
  # A rule that disallows multi-line blocks that use curly brackets
  # instead of `do`...`end`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # (0..10).map { |i|
  #   i * 2
  # }
  # ```
  #
  # And should be rewritten to the following:
  #
  # ```
  # (0..10).map do |i|
  #   i * 2
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/MultilineCurlyBlock:
  #   Enabled: true
  # ```
  class MultilineCurlyBlock < Base
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
