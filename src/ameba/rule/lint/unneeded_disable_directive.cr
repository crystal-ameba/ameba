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
          # The directive stays if it still disables any rule or group, along
          # with the other words, like a reason or a misspelled rule name.
          if (rules - names).any?(&->known_rule_or_group?(String))
            corrector.replace(*location, without_rules(token.value.to_s, names))
          else
            corrector.remove(*location)
          end
        end
      end
    end

    # Removes the *names* from the directive in the *comment*, each one along
    # with a separator, leaving the rest of the *comment* as it was.
    private def without_rules(comment, names)
      comment.sub(InlineComments::COMMENT_DIRECTIVE_REGEX) do |_, match|
        rules = String.build do |io|
          match["rules"].scan(/(,? )?(\w+(?:\/\w+)?)/) do |rule_match|
            next if rule_match[2].in?(names)

            io << rule_match[1]? unless io.bytesize.zero?
            io << rule_match[2]
          end
        end

        "# ameba:#{match["action"]} #{rules}"
      end
    end

    private def known_rule?(rule_name)
      Rule.rules.any?(&.rule_name.== rule_name)
    end

    private def known_rule_or_group?(name)
      Rule.rules.any? { |rule| rule.rule_name == name || rule.group_name == name }
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
