module Ameba::Rule::Lint
  # A rule that reports incorrect comment directives for Ameba.
  #
  # ```
  # # ameba:off Lint/NotNil
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

    MSG = "Bad action in comment directive: `%s`. Possible values: %s"

    AVAILABLE_ACTIONS = InlineComments::Action
      .names
      .map!(&.underscore.gsub('_', '-'))

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless directive = source.parse_inline_directive(token.value.to_s)

        check_action source, token, directive[:action]
      end
    end

    private def check_action(source, token, action)
      return if InlineComments::Action.parse?(action)

      # See `InlineComments::COMMENT_DIRECTIVE_REGEX`
      prefix_size = {{ "# ameba:".size }}

      issue_for name_location_or(token, action, adjust_location_column_number: prefix_size),
        MSG % {action, AVAILABLE_ACTIONS.map { |name| "`#{name}`" }.join(", ")}
    end
  end
end
