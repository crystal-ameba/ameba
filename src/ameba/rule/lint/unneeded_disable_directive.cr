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
  # Lint/UnneededDisableDirective:
  #   Enabled: true
  # ```
  class UnneededDisableDirective < Base
    include AST::Util

    properties do
      since_version "0.5.0"
      description "Reports unneeded disable directives in comments"
    end

    MSG = "Unnecessary disabling of %s"

    def test(source)
      test(source, Set(String).new)
    end

    def test(source, excluded_rules : Set(String))
      each_inline_directive(source) do |token, action, rules|
        next unless action == "disable"

        next unless names = unneeded_disables(source, rules, token.location, excluded_rules)
        next unless names.present?

        message = MSG % names.map { |name| "`#{name}`" }.join(", ")
        location = name_location_or(token, token.value)

        issue_for(*location, message) do |corrector|
          # Keeps the rules which are needed, or whose need is unknown.
          # Other words, like a reason following the rules, are dropped.
          kept_rules = (rules - names).select(&->known_rule?(String))

          if kept_rules.empty?
            corrector.remove(*location)
          else
            corrector.replace(*location, disable_directive(token.value.to_s, kept_rules))
          end
        end
      end
    end

    private def disable_directive(comment, rules)
      comment.sub(InlineComments::COMMENT_DIRECTIVE_REGEX,
        "# ameba:disable #{rules.join(", ")}")
    end

    private def known_rule?(rule_name)
      Rule.rules.any?(&.rule_name.== rule_name)
    end

    private def unneeded_disables(source, rules, location, excluded_rules)
      rules.select do |rule_name|
        next true if rule_name == name

        next if rule_name.in?(excluded_rules)
        next unless known_rule?(rule_name)

        source.issues.none? do |issue|
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
