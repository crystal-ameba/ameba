module Ameba::Rule::Style
  # A rule that enforces _Heredoc_ bodies be indented one level above the indentation of the
  # line they're used on.
  #
  # For example, this is considered invalid:
  #
  # ```
  # call <<-HERERDOC
  #   hello world
  # HEREDOC
  #
  # begin
  #   call <<-HERERDOC
  # hello world
  # HEREDOC
  # end
  # ```
  #
  # And should be written as:
  #
  # ```
  # call <<-HERERDOC
  #     hello world
  #   HEREDOC
  #
  # begin
  #   call <<-HERERDOC
  #     hello world
  #     HEREDOC
  # end
  # ```
  #
  # The `SameLine` configuration option enforces that the _heredoc_ body have the same indent as the
  # line it is used on.
  #
  # ```
  # Style/HeredocIndent:
  #   Enabled: true
  #   SameLine: true
  # ```
  class HeredocIndent < Base
    properties do
      since_version "1.7.0"
      description "Recommends heredoc bodies be indented exactly one level above the line they're used on"
      indent_by 2
    end

    MSG = "Heredoc body should be indented by %s spaces"

    def test(source, node : Crystal::StringInterpolation)
      return unless start_location = node.location
      start_location_pos = source.pos(start_location)
      return unless source.code[start_location_pos..(start_location_pos + 2)]? == "<<-"

      correct_indent = line_indent(source, start_location) + (same_line? ? 0 : 2)

      unless node.heredoc_indent == indent_by
        issue_for node, MSG % correct_indent
      end
    end

    def line_indent(source, start_location) : Int32
      line_location = Crystal::Location.new(filename: nil, line_number: start_location.line_number, column_number: 1)

      line = source.code[source.pos(line_location)..(source.pos(line_location) + start_location.column_number)]

      line.size - line.lstrip.size
    end
  end
end
