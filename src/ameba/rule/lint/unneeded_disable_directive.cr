module Ameba::Rule::Lint
  # A rule that reports unneeded disable directives.
  # For example, this is considered invalid:
  #
  # ```
  # # ameba:disable Style/PredicateName
  # def comment?
  #   do_something
  # end
  # ```
  #
  # As the predicate name is correct and the comment directive does not
  # have any effect, the snippet should be written as the following:
  #
  # ```
  # def comment?
  #   do_something
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnneededDisableDirective
  #   Enabled: true
  # ```
  class UnneededDisableDirective < Base
    properties do
      since_version "0.5.0"
      description "Reports unneeded disable directives in comments"
    end

    MSG = "Unnecessary disabling of %s"

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless directive = source.parse_inline_directive(token.value.to_s)
        next unless names = unneeded_disables(source, directive, token.location)
        next if names.empty?

        issue_for token, MSG % names.join(", ")
      end
    end

    private def unneeded_disables(source, directive, location)
      return unless directive[:action] == "disable"

      directive[:rules].reject do |rule_name|
        next if rule_name == name
        source.issues.any? do |issue|
          issue.rule.name == rule_name &&
            issue.disabled? &&
            issue_at_location?(source, issue, location)
        end
      end
    end

    private def issue_at_location?(source, issue, location)
      return false unless issue_line_number = issue.location.try(&.line_number)

      issue_line_number == location.line_number ||
        ((prev_line_number = issue_line_number - 1) &&
          prev_line_number == location.line_number &&
          source.comment?(prev_line_number - 1))
    end
  end
end
