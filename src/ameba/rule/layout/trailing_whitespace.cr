module Ameba::Rule::Layout
  # A rule that disallows trailing whitespaces.
  #
  # YAML configuration example:
  #
  # ```
  # Layout/TrailingWhitespace:
  #   Enabled: true
  # ```
  class TrailingWhitespace < Base
    properties do
      description "Disallows trailing whitespaces"
    end

    MSG = "Trailing whitespace detected"

    def test(source)
      source.lines.each_with_index do |line, index|
        issue_for({index + 1, line.size}, MSG) if line =~ /\s$/
      end
    end
  end
end
