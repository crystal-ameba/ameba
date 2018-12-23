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

    MSG = "Blank lines detected at the end of the file"

    def test(source)
      if source.lines.size > 1 && source.lines[-2, 2].join.strip.empty?
        issue_for({source.lines.size - 1, 1}, MSG)
      end
    end
  end
end
