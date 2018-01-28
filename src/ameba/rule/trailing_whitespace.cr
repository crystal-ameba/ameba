module Ameba::Rule
  # A rule that disallows trailing whitespaces.
  #
  # YAML configuration example:
  #
  # ```
  # TrailingWhitespace:
  #   Enabled: true
  # ```
  #
  struct TrailingWhitespace < Base
    properties do
      description = "Disallows trailing whitespaces"
    end

    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line =~ /\s$/
        source.error self, index + 1, line.size, "Trailing whitespace detected"
      end
    end
  end
end
