module Ameba::Rule::Lint
  # A rule that reports incorrect comment directives for Ameba.
  #
  # For example, the user can mistakenly add a directive
  # to disable a rule that even doesn't exist:
  #
  # ```
  # # ameba:disable BadRuleName
  # def foo
  #   :bar
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/BadDirective:
  #   Enabled: true
  # ```
  class BadDirective < Base
    include AST::Util

    properties do
      since_version "0.13.0"
      description "Reports bad comment directives"
    end

    MSG_INVALID_ACTION    = "Bad action in comment directive: `%s`. Possible values: %s"
    MSG_NONEXISTENT_RULES = "Such rules do not exist: %s"

    AVAILABLE_ACTIONS = InlineComments::Action
      .names
      .map!(&.underscore.gsub('_', '-'))

    ALL_RULE_NAMES  = Rule.rules.map(&.rule_name)
    ALL_GROUP_NAMES = Rule.rules.map(&.group_name).uniq!

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless directive = source.parse_inline_directive(token.value.to_s)

        check_action source, token, directive[:action]
        check_rules source, token, directive[:rules]
      end
    end

    private def check_action(source, token, action)
      return if InlineComments::Action.parse?(action)

      # See `InlineComments::COMMENT_DIRECTIVE_REGEX`

      issue_for name_location_or(token, action, adjust_location_column_number: {{ "# ameba:".size }}),
        MSG_INVALID_ACTION % {
          action, AVAILABLE_ACTIONS.map { |name| "`#{name}`" }.join(", "),
        }
    end

    private def check_rules(source, token, rules)
      bad_names = rules - ALL_RULE_NAMES - ALL_GROUP_NAMES
      return if bad_names.empty?

      issue_for name_location_or(token, token.value),
        MSG_NONEXISTENT_RULES % bad_names.map { |name| "`#{name}`" }.join(", ")
    end
  end
end
