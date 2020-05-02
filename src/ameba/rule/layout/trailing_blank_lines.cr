module Ameba::Rule::Layout
  # A rule that disallows trailing blank lines at the end of the source file.
  #
  # YAML configuration example:
  #
  # ```
  # Layout/TrailingBlankLines:
  #   Enabled: true
  # ```
  #
  struct TrailingBlankLines < Base
    properties do
      description "Disallows trailing blank lines"
    end

    MSG               = "Blank lines detected at the end of the file"
    MSG_FINAL_NEWLINE = "Final newline missing"

    def test(source)
      source_lines = source.lines
      last_source_line = source_lines.last
      source_lines_size = source.lines.size
      return if source_lines_size == 1 && last_source_line.empty?

      last_line_not_empty = !last_source_line.strip.empty?
      if source.lines.size >= 1 && (source_lines.last(2).join.strip.empty? || last_line_not_empty)
        issue_for({source_lines_size - 1, 1}, last_line_not_empty ? MSG_FINAL_NEWLINE : MSG)
      end
    end
  end
end
