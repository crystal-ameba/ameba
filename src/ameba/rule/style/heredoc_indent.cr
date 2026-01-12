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
  # If `BodyAutoDedent` is enabled (default), the body of the _heredoc_ will be
  # automatically dedented to the minimum indentation level of the body lines.
  #
  # For example:
  #
  # ```
  # <<-HEREDOC
  #   <article>
  #     ...
  #   </article>
  # HEREDOC
  # ```
  #
  # Will be automatically dedented to:
  #
  # ```
  # <<-HEREDOC
  #   <article>
  #     ...
  #   </article>
  #   HEREDOC
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/HeredocIndent:
  #   Enabled: true
  #   IndentBy: 2
  #   BodyAutoDedent: true
  # ```
  class HeredocIndent < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Recommends heredoc bodies are indented consistently"
      indent_by 2
      body_auto_dedent true
    end

    MSG = "Heredoc body should be indented by %d spaces"

    def test(source, node : Crystal::StringInterpolation)
      return unless location = node.location

      return unless node_source = node_source(node, source.lines)
      return unless node_source.starts_with?("<<-")

      correct_indent = line_indent(source, location) + indent_by
      heredoc_indent = node.heredoc_indent

      return if heredoc_indent == correct_indent

      issue_for node, MSG % indent_by do |corrector|
        source_lines = node_source.lines
        body_dedent =
          if body_auto_dedent?
            source_lines[1...-1]
              .reject!(&.empty?)
              .min_of(&.each_char.take_while(&.whitespace?).size)
          end
        body_dedent ||= heredoc_indent

        corrected_code = source_lines
          .map_with_index! do |line, idx|
            # ignore 1st line containing the marker
            next line if idx.zero? || line.empty?

            dedent =
              idx == source_lines.size - 1 ? heredoc_indent : body_dedent

            "#{" " * correct_indent}#{line[dedent..]}"
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
