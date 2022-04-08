module Ameba
  # A module that utilizes inline comments parsing and processing logic.
  module InlineComments
    COMMENT_DIRECTIVE_REGEX = /# ameba:(?<action>\w+) (?<names>\w+(?:\/\w+)?(?:,? \w+(?:\/\w+)?)*)/

    # Available actions in the inline comments
    enum Action
      Enable
      Disable
      DisableLine
      DisableNextLine
    end

    # Directive the inline comment is parsed to.
    struct Directive
      getter action : Action
      getter names : Array(String)
      getter line_number : Int32

      def initialize(@action, @names, @line_number)
      end

      def includes?(rule)
        rule.name.in?(names) || rule.group.in?(names)
      end
    end

    # Returns true if current location is disabled for a particular rule,
    # false otherwise.
    #
    # Location can be disabled in the following cases:
    #   1. The line of the location ends with ameba:disable_line directive
    #   2. The line above the location ends with ameba:disable_next_line directive
    #   3. Any line above the location ends with ameba:disable directive
    #
    # Note: if there is ameba:enable directive which follows the ameba:disable
    # directive with the same rule name, it is automatically re-enabled.
    #
    # For example, in all the cases below directive disables the rule:
    #
    # ```
    # Time.epoch(1483859302) # ameba:disable_line Style/LargeNumbers
    #
    # # ameba:disable_next_line Style/LargeNumbers
    # Time.epoch(1483859302)
    #
    # # ameba:disable Style/LargeNumbers
    # Time.epoch(1483859301)
    # Time.epoch(1483859302)
    # ```
    #
    # In the case below the rule is not disabled and reports and issue:
    #
    # ```
    # # ameba:disable Style/LargeNumbers
    # # ameba:enable Style/LargeNumbers
    # Time.epoch(1483859302)
    # ```
    def location_disabled?(location, rule)
      return false if directives.empty? || rule.name.in?(Rule::SPECIAL)
      return false unless line_number = location.try &.line_number

      line_disabled?(line_number, rule) ||
        next_line_disabled?(line_number, rule) ||
        region_disabled?(line_number, rule)
    end

    def parse_directives(lines)
      ([] of Directive).tap do |directives|
        lines.each_with_index do |line, line_number|
          next unless d = parse_directive(line, line_number + 1)
          directives << d
        end
      end
    end

    # Parses inline comment directive. Returns a tuple that consists of
    # an action and parsed rules if directive found, nil otherwise.
    #
    # ```
    # line = "# ameba:disable Rule1, Rule2"
    # directive = parse_directive(line, 1)
    # directive.action # => "disable"
    # directive.rules  # => ["Rule1", "Rule2"]
    # ```
    #
    # It ignores the directive if it is commented out.
    #
    # ```
    # line = "# # ameba:disable Rule1, Rule2"
    # parse_directive(line) # => nil
    # ```
    def parse_directive(line : String, line_number : Int32)
      return unless match = match_inline_comment(line)
      return unless action = Action.parse?(match[:action])
      Directive.new(action: action, names: match[:names], line_number: line_number)
    end

    def match_inline_comment(line)
      return unless match = COMMENT_DIRECTIVE_REGEX.match(line)
      return if commented_out?(line.gsub(match[0], ""))

      {
        action: match[1],
        names:  match[2].split(/[\s,]/, remove_empty: true),
      }
    end

    # Returns true if the line at the given `line_number` is a comment.
    def comment?(line_number : Int32)
      return unless line = lines[line_number]?
      comment?(line)
    end

    private def comment?(line : String)
      line.lstrip.starts_with? '#'
    end

    # Disabled by ameba:disable_line <RuleName>
    private def line_disabled?(line_number, rule)
      return false unless directive = find_directive(line_number)
      directive.action.disable_line? && directive.includes?(rule)
    end

    # Disabled by ameba:disable_next_line <RuleName>
    private def next_line_disabled?(line_number, rule)
      return false unless directive = find_directive(line_number - 1)
      directive.action.disable_next_line? && directive.includes?(rule)
    end

    # Disabled by ameba:disable <RuleName>
    private def region_disabled?(line_number, rule)
      directives
        .select { |d| d.line_number <= line_number && (d.action.disable? || d.action.enable?) }
        .reverse!
        .find(&.includes?(rule))
        .try &.action.disable?
    end

    private def find_directive(line_number)
      directives.find { |d| d.line_number == line_number }
    end

    private def commented_out?(line)
      commented = false

      lexer = Crystal::Lexer.new(line).tap(&.comments_enabled = true)
      Tokenizer.new(lexer).run { |t| commented = true if t.type.comment? }
      commented
    end
  end
end
