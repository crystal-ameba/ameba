module Ameba::Rule::Layout
  # A rule that disallows lines longer than `max_length` number of symbols.
  #
  # YAML configuration example:
  #
  # ```
  # Layout/LineLength:
  #   Enabled: true
  #   MaxLength: 100
  # ```
  class LineLength < Base
    properties do
      enabled false
      description "Disallows lines longer than `MaxLength` number of symbols"
      max_length 140
    end

    MSG = "Line too long"

    def test(source)
      source.lines.each_with_index do |line, index|
        issue_for({index + 1, max_length + 1}, MSG) if line.size > max_length
      end
    end
  end
end
