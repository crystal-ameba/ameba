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
  struct LineLength < Base
    prop max_length = 80

    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line.size > max_length

        source.error self, source.location(index + 1, line.size),
          "Line too long"
      end
    end
  end
end
