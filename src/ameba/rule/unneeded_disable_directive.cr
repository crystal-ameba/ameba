module Ameba::Rule
  # A rule that reports unneeded disable directives.
  # For example, this is considered invalid:
  #
  # ```
  # # ameba:disable PredicateName
  # def comment?
  #   do_something
  # end
  # ```
  #
  # as the predicate name is correct and the comment directive does not
  # have any effect, the snippet should be written as the following:
  #
  # ```
  # def comment?
  #   do_something
  # end
  # ```
  #
  struct UnneededDisableDirective < Base
    properties do
      description = "Reports unneeded disable directives in comments"
    end

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type == :COMMENT
        next unless directive = source.parse_inline_directive(token.value.to_s)
        next unless names = unneeded_disables(source, directive, token.location)
        next unless names.any?

        source.error self, token.location,
          "Unnecessary disabling of #{names.join(", ")}"
      end
    end

    private def unneeded_disables(source, directive, location)
      return unless directive[:action] == "disable"

      directive[:rules].reject do |rule_name|
        source.errors.any? do |error|
          error.rule.name == rule_name &&
            error.disabled? &&
            error.location.try(&.line_number) == location.line_number
        end && rule_name != self.name
      end
    end
  end
end
