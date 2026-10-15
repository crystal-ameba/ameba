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
      return if !source_lines.last(2).all?(&.empty?) && last_line_empty

      newline =
        source.code.includes?("\r\n") ? "\r\n" : "\n"

      if last_line_empty
        replacement = source.code.rstrip("\r\n")
        replacement += newline unless replacement.empty?

        diff =
          source_lines_size - replacement.each_line.size

        location = {source_lines_size - diff + 1, 1}
        end_location = {source_lines_size, 1}

        issue_for(location, end_location, MSG) do |corrector|
          corrector.replace(0...source.code.size, replacement)
        end
      else
        location = {source_lines_size, 1}
        end_location = {source_lines_size, last_source_line.size}

        issue_for(location, end_location, MSG_FINAL_NEWLINE) do |corrector|
          corrector.insert_before(source.code.size, newline)
        end
      end
    end
  end
end
