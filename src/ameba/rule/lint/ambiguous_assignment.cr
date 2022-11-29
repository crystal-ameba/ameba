module Ameba::Rule::Lint
  # This rule checks for mistyped shorthand assignments.
  #
  #     # bad
  #     x =- y
  #     x =+ y
  #     x =! y
  #
  #     # good
  #     x -= y # or x = -y
  #     x += y # or x = +y
  #     x != y # or x = !y
  #
  # YAML configuration example:
  #
  # ```
  # Lint/AmbiguousAssignment:
  #   Enabled: true
  # ```
  class AmbiguousAssignment < Base
    include AST::Util

    properties do
      description "Disallows ambiguous `=-/=+/=!`"
    end

    MSG = "Suspicious assignment detected. Did you mean `%s`?"

    MISTAKES = {
      "=-" => "-=",
      "=+" => "+=",
      "=!" => "!=",
    }

    def test(source, node : Crystal::Assign)
      return unless op_end_location = node.value.location

      op_location = Crystal::Location.new(
        op_end_location.filename,
        op_end_location.line_number,
        op_end_location.column_number - 1
      )
      op_text = source_between(op_location, op_end_location, source.lines)

      return unless op_text
      return unless MISTAKES.has_key?(op_text)

      issue_for op_location, op_end_location, MSG % MISTAKES[op_text]
    end
  end
end
