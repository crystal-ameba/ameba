module Ameba::Rule::Layout
  # A rule that disallows trailing whitespace.
  #
  # YAML configuration example:
  #
  # ```
  # Layout/TrailingWhitespace:
  #   Enabled: true
  # ```
  class TrailingWhitespace < Base
    properties do
      description "Disallows trailing whitespace"
    end

    MSG = "Trailing whitespace detected"

    def test(source)
      source.lines.each_with_index do |line, index|
        next unless ws_index = line =~ /\s+$/

        location = {index + 1, ws_index + 1}
        end_location = {index + 1, line.size}

        issue_for location, end_location, MSG do |corrector|
          corrector.remove(location, end_location)
        end
      end
    end
  end
end
