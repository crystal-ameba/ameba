module Ameba::Rule::Lint
  # This rule checks for mistyped shorthand assignments.
  #
  # ```
  # # bad
  # x =- y
  # x =+ y
  # x =! y
  #
  # # good
  # x -= y # or x = -y
  # x += y # or x = +y
  # x != y # or x = !y
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/AmbiguousAssignment:
  #   Enabled: true
  # ```
  class AmbiguousAssignment < Base
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
      return if (op_end_location = node.value.location).nil?

      op_location = Crystal::Location.new(op_end_location.filename,
                                          op_end_location.line_number,
                                          op_end_location.column_number - 1)
      op_text = source.text_in_range(op_location, op_end_location)
      return unless MISTAKES.has_key?(op_text)

      issue_for op_location, op_end_location, MSG % MISTAKES[op_text]
    end
  end
end
