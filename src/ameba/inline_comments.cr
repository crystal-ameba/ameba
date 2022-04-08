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

      def initialize(@action, @names)
      end

      def includes?(rule)
        rule.name.in?(names) || rule.group.in?(names)
      end
    end

    # Map of directives.
    # Key is a line number, value is a Directive itself.
    alias Directives = Hash(Int32, Directive)

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
    # # ameba:disable Style/LargeNumbers
    # Time.epoch(1483859302)
    #
    # Time.epoch(1483859302) # ameba:disable Style/LargeNumbers
    # ```
    #
    # But here are examples which are not considered as disabled location:
    #
    # ```
    # # ameba:disable Style/LargeNumbers
    # #
    # Time.epoch(1483859302)
    #
    # if use_epoch? # ameba:disable Style/LargeNumbers
    #   Time.epoch(1483859302)
    # end
    # ```
    def location_disabled?(location, rule)
      return false if directives.empty?
      return false if rule.name.in?(Rule::SPECIAL)
      return false unless line_number = location.try &.line_number

      line_disabled?(line_number, rule) ||
        next_line_disabled?(line_number, rule)
    end

    def parse_directives(lines)
      Directives.new.tap do |directives|
        lines.each_with_index do |line, line_number|
          next unless d = parse_directive(line)
          directives[line_number + 1] = d
        end
      end
    end

    # Parses inline comment directive. Returns a tuple that consists of
    # an action and parsed rules if directive found, nil otherwise.
    #
    # ```
    # line = "# ameba:disable Rule1, Rule2"
    # directive = parse_directive(line)
    # directive[:action] # => "disable"
    # directive[:rules]  # => ["Rule1", "Rule2"]
    # ```
    #
    # It ignores the directive if it is commented out.
    #
    # ```
    # line = "# # ameba:disable Rule1, Rule2"
    # parse_directive(line) # => nil
    # ```
    def parse_directive(line)
      return unless match = match_inline_comment(line)
      return unless action = Action.parse?(match[:action])
      Directive.new(action: action, names: match[:names])
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

    private def line_disabled?(line_number, rule)
      return false unless directive = directives[line_number]?
      directive.action.disable_line? && directive.includes?(rule)
    end

    private def next_line_disabled?(line_number, rule)
      return false unless directive = directives[line_number - 1]?
      directive.action.disable_next_line? && directive.includes?(rule)
    end

    private def commented_out?(line)
      commented = false

      lexer = Crystal::Lexer.new(line).tap(&.comments_enabled = true)
      Tokenizer.new(lexer).run { |t| commented = true if t.type.comment? }
      commented
    end
  end
end
