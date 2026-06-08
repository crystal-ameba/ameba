module Ameba::Rule::Lint
  # A rule that reports deprecated rules in comment directives.
  #
  # ```
  # # ameba:disable DeprecatedRuleName
  # def foo
  #   :bar
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DeprecatedRule:
  #   Enabled: true
  # ```
  class DeprecatedRule < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Reports deprecated rules in comment directives"
    end

    MSG_ONE  = "Deprecated rule: %s"
    MSG_MANY = "Deprecated rules: %s"

    ALL_DEPRECATED_RULES = Rule.rules.select(&.deprecated?)

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless directive = source.parse_inline_directive(token.value.to_s)

        check_rules source, token, directive[:action], directive[:rules]
      end
    end

    private def check_rules(source, token, action, rules)
      deprecated_rules = ALL_DEPRECATED_RULES.select(&.rule_name.in?(rules))
      return if deprecated_rules.empty?

      # See `InlineComments::COMMENT_DIRECTIVE_REGEX`
      prefix_size = "# ameba:#{action} ".size
      token_value = token.value.to_s[prefix_size - 1...-1]?

      msg = deprecated_rules.size == 1 ? MSG_ONE : MSG_MANY
      msg = msg % deprecated_rules.map do |rule|
        str = "`#{rule.rule_name}`"
        if deprecation_reason = rule.deprecation_reason
          str += " (#{deprecation_reason})"
        end
        str
      end.join(", ")

      issue_for name_location_or(token, token_value, adjust_location_column_number: prefix_size),
        msg
    end
  end
end
