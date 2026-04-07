module Ameba::Rule::Lint
  # A rule that reports non-existent rules in comment directives.
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
  # Lint/NonExistentRule:
  #   Enabled: true
  # ```
  class NonExistentRule < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Reports non-existent rules in comment directives"
    end

    MSG = "Such rules do not exist: %s"

    ALL_RULE_NAMES  = Rule.rules.map(&.rule_name)
    ALL_GROUP_NAMES = Rule.rules.map(&.group_name).uniq!

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless directive = source.parse_inline_directive(token.value.to_s)

        check_rules source, token, directive[:rules]
      end
    end

    private def check_rules(source, token, rules)
      bad_names = rules - ALL_RULE_NAMES - ALL_GROUP_NAMES
      return if bad_names.empty?

      issue_for name_location_or(token, token.value),
        MSG % bad_names.map { |name| "`#{name}`" }.join(", ")
    end
  end
end
