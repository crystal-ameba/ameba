module Ameba::Rule::Style
  # A rule that disallows multiline string literals not using
  # `<<-HEREDOC` markers.
  #
  # For example, this is considered invalid:
  #
  # ```
  # %(
  #   foo
  #   bar
  # )
  # ```
  #
  # And should be rewritten to the following:
  #
  # ```
  # <<-HEREDOC
  #   foo
  #   bar
  # HEREDOC
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/MultilineStringLiteral:
  #   Enabled: true
  #   AllowBackslashSplitStrings: true
  # ```
  class MultilineStringLiteral < Base
    properties do
      since_version "1.7.0"
      description "Disallows multiline string literals not using `<<-HEREDOC` markers"
      allow_backslash_split_strings true
    end

    MSG = "Use `<<-HEREDOC` markers for multiline strings"

    def test(source, node : Crystal::StringLiteral | Crystal::StringInterpolation)
      return unless location = node.location
      return if location.same_line?(node.end_location)

      location_pos = source.pos(location)

      # ignore command and regex literals
      return if source.code[location_pos]?.in?('`', '/')

      # ignore heredoc string literals
      return if source.code[location_pos..(location_pos + 2)]? == "<<-"

      # ignore string literals split by \
      return if allow_backslash_split_strings? &&
                source.code.lines[location.line_number - 1].ends_with?('\\')

      issue_for node, MSG
    end
  end
end
