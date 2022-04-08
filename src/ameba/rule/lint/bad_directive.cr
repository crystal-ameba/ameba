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
    properties do
      description "Reports bad comment directives"
    end

    AVAILABLE_ACTIONS = InlineComments::Action.names.map(&.underscore)
    ALL_RULE_NAMES    = Rule.rules.map(&.rule_name)
    ALL_GROUP_NAMES   = Rule.rules.map(&.group_name).uniq!

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless match = source.match_inline_comment(token.value.to_s)

        check_action source, token, match[:action]
        check_rules source, token, match[:names]
      end
    end

    private def check_action(source, token, action)
      return if InlineComments::Action.parse?(action)

      issue_for token,
        "Bad action in comment directive: '%s'. Possible values: %s" % {
          action, AVAILABLE_ACTIONS.join(", "),
        }
    end

    private def check_rules(source, token, rules)
      bad_names = rules - ALL_RULE_NAMES - ALL_GROUP_NAMES
      return if bad_names.empty?

      issue_for token, "Such rules do not exist: %s" % bad_names.join(", ")
    end
  end
end
