module Ameba::Rule
  # A rule that disallows trailing blank lines at the end of the source file.
  #
  # YAML configuration example:
  #
  # ```
  # TrailingBlankLines:
  #   Enabled: true
  # ```
  #
  struct TrailingBlankLines < Base
    properties do
      description = "Disallows trailing blank lines"
    end

    def test(source)
      if source.lines.size > 1 && source.lines[-2, 2].join.strip.empty?
        source.error self, source.lines.size, 1,
          "Blank lines detected at the end of the file"
      end
    end
  end
end
