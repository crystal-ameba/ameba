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
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Recommends heredoc bodies are indented consistently"
      indent_by 2
    end

    MSG = "Heredoc body should be indented by %d spaces"

    def test(source, node : Crystal::StringInterpolation)
      return unless location = node.location

      return unless node_source = node_source(node, source.lines)
      return unless node_source.starts_with?("<<-")

      correct_indent = line_indent(source, location) + indent_by
      return if node.heredoc_indent == correct_indent

      issue_for node, MSG % indent_by do |corrector|
        corrected_code = node_source
          .lines
          .map_with_index! do |line, idx|
            # ignore 1st line containing the marker
            idx.zero? ? line : "#{" " * correct_indent}#{line.lstrip}"
          end
          .join('\n')

        corrector.replace(node, corrected_code)
      end
    end

    private def line_indent(source, location) : Int32
      line_location = location.with(column_number: 1)
      line_location_pos = source.pos(line_location)
      line = source.code[line_location_pos..(line_location_pos + location.column_number)]

      line.size - line.lstrip.size
    end
  end
end
