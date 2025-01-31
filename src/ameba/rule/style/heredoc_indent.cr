module Ameba::Rule::Style
  # A rule that enforces _Heredoc_ bodies be indented one level above the indentation of the
  # line they're used on.
  #
  # For example, this is considered invalid:
  #
  # ```
  # <<-HERERDOC
  #   hello world
  # HEREDOC
  #
  #   <<-HERERDOC
  # hello world
  # HEREDOC
  # ```
  #
  # And should be written as:
  #
  # ```
  # <<-HERERDOC
  #     hello world
  #   HEREDOC
  #
  #   <<-HERERDOC
  #     hello world
  #     HEREDOC
  # ```
  #
  # The `IndentBy` configuration option changes the enforced indentation level of the _heredoc_.
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

    MSG = "Heredoc body should be indented by %s spaces"

    def test(source, node : Crystal::StringInterpolation)
      return unless start_location = node.location

      start_location_pos = source.pos(start_location)
      return unless source.code[start_location_pos..(start_location_pos + 2)]? == "<<-"

      correct_indent = line_indent(source, start_location) + indent_by

      unless node.heredoc_indent == correct_indent
        issue_for node, MSG % indent_by
      end
    end

    private def line_indent(source, start_location) : Int32
      line_location = Crystal::Location.new(nil, start_location.line_number, 1)
      line_location_pos = source.pos(line_location)
      line = source.code[line_location_pos..(line_location_pos + start_location.column_number)]

      line.size - line.lstrip.size
    end
  end
end
