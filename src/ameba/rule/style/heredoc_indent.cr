module Ameba::Rule::Style
  # A rule that enforces _heredoc_ bodies be indented one level above the
  # indentation of the line they're used on.
  #
  # For example, this is considered invalid:
  #
  #     <<-HEREDOC
  #       hello world
  #     HEREDOC
  #
  #       <<-HEREDOC
  #     hello world
  #     HEREDOC
  #
  # And should be written as:
  #
  #     <<-HEREDOC
  #         hello world
  #       HEREDOC
  #
  #     <<-HEREDOC
  #       hello world
  #       HEREDOC
  #
  # The `IndentBy` configuration option changes the enforced indentation level
  # of the _heredoc_.
  #
  # YAML configuration example:
  #
  # ```
  # Style/HeredocIndent:
  #   Enabled: true
  #   IndentBy: 2
  # ```
  class HeredocIndent < Base
    properties do
      since_version "1.7.0"
      description "Recommends heredoc bodies are indented consistently"
      indent_by 2
    end

    MSG = "Heredoc body should be indented by %d spaces"

    def test(source, node : Crystal::StringInterpolation)
      return unless location = node.location

      location_pos = source.pos(location)
      return unless source.code[location_pos..(location_pos + 2)]? == "<<-"

      correct_indent = line_indent(source, location) + indent_by
      return if node.heredoc_indent == correct_indent

      issue_for node, MSG % indent_by
    end

    private def line_indent(source, location) : Int32
      line_location = location.with(column_number: 1)
      line_location_pos = source.pos(line_location)
      line = source.code[line_location_pos..(line_location_pos + location.column_number)]

      line.size - line.lstrip.size
    end
  end
end
