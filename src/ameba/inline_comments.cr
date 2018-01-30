module Ameba
  # A module that represents inline comments parsing and processing logic.
  module InlineComments
    COMMENT_DIRECTIVE_REGEX = Regex.new "# ameba : (\\w+) ([\\w, ]+)".gsub(" ", "\\s*")

    # Returns true if current location is disabled for a particular rule,
    # false otherwise.
    #
    # Location is disabled in two cases:
    #   1. The line of the location ends with a comment directive.
    #   2. The line above the location is a comment directive.
    #
    # For example, here are two examples of disabled location:
    #
    # ```
    # # ameba:disable LargeNumbers
    # Time.epoch(1483859302)
    #
    # Time.epoch(1483859302) # ameba:disable LargeNumbers
    # ```
    #
    # But here are examples which are not considered as disabled location:
    #
    # ```
    # # ameba:disable LargeNumbers
    # #
    # Time.epoch(1483859302)
    #
    # if use_epoch? # ameba:disable LargeNumbers
    #   Time.epoch(1483859302)
    # end
    # ```
    #
    def location_disabled?(location, rule)
      return false unless line_number = location.try &.line_number.try &.- 1
      return false unless line = lines[line_number]?

      line_disabled?(line, rule) ||
        (line_number > 0 &&
          (prev_line = lines[line_number - 1]) &&
          comment?(prev_line) &&
          line_disabled?(prev_line, rule))
    end

    private def comment?(line)
      line.lstrip.starts_with? '#'
    end

    private def line_disabled?(line, rule)
      return false unless inline_comment = parse_inline_comment(line)
      inline_comment[:action] == "disable" && inline_comment[:rules].includes?(rule)
    end

    private def parse_inline_comment(line)
      if comment = COMMENT_DIRECTIVE_REGEX.match(line)
        {
          action: comment[1],
          rules:  comment[2].split(/[\s,]/, remove_empty: true),
        }
      end
    end
  end
end
