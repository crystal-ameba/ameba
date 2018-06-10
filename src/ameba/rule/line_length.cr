module Ameba::Rule
  # A rule that disallows lines longer than `max_length` number of symbols.
  #
  # YAML configuration example:
  #
  # ```
  # LineLength:
  #   Enabled: true
  #   MaxLength: 100
  # ```
  #
  struct LineLength < Base
    properties do
      enabled false
      description "Disallows lines longer than `MaxLength` number of symbols"
      max_length 80
    end

    MSG = "Line too long"

    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line.size > max_length

        issue_for({index + 1, line.size}, MSG)
      end
    end
  end
end
