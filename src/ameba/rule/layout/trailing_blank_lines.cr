module Ameba::Rule::Layout
  # A rule that disallows trailing blank lines at the end of the source file.
  #
  # YAML configuration example:
  #
  # ```
  # Layout/TrailingBlankLines:
  #   Enabled: true
  # ```
  class TrailingBlankLines < Base
    properties do
      since_version "0.1.0"
      description "Disallows trailing blank lines"
    end

    MSG               = "Excessive trailing newline detected"
    MSG_FINAL_NEWLINE = "Trailing newline missing"

    def test(source)
      source_lines = source.lines
      return if source_lines.empty?

      last_source_line = source_lines.last
      source_lines_size = source_lines.size
      return if source_lines_size == 1 && last_source_line.empty?

      last_line_empty = last_source_line.empty?
      return if source_lines_size.zero? ||
                (source_lines.last(2).join.presence && last_line_empty)

      location = {source_lines_size, 1}

      if last_line_empty
        issue_for location, MSG
      else
        issue_for location, MSG_FINAL_NEWLINE do |corrector|
          corrector.insert_before({source_lines_size + 1, 1}, '\n')
        end
      end
    end
  end
end
