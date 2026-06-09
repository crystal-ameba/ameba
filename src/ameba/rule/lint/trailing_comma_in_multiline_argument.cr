module Ameba::Rule::Lint
  # A rule that enforces trailing comma in multiline call argument lists.
  #
  # For example, this is considered invalid:
  #
  # ```
  # foo(
  #   bar,
  #   baz
  # )
  # ```
  #
  # and it should be written as follows:
  #
  # ```
  # foo(
  #   bar,
  #   baz,
  # )
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/TrailingCommaInMultilineArgument:
  #   Enabled: true
  # ```
  class TrailingCommaInMultilineArgument < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces trailing comma in multiline call argument lists"
    end

    MSG = "Missing trailing comma after the last call argument"

    def test(source, node : Crystal::Call)
      return if node.location.try(&.same_line?(node.end_location))
      return if !node.has_parentheses? || setter_method?(node)

      last = node.named_args.try(&.last?) ||
             node.args.last?

      check_last_argument(source, last) if last
    end

    private def check_last_argument(source, node)
      return if heredoc?(node, source)

      return unless end_location = node.end_location
      return unless line = source.lines[end_location.line_number - 1]?
      return unless remainder = line[end_location.column_number..]?

      return if remainder.lstrip[0]?.in?(',', ')')

      issue_for node, MSG do |corrector|
        corrector.insert_after(end_location, ',')
      end
    end
  end
end
