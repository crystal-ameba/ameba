module Ameba::Rule::Style
  class HeredocEscape < Base
    properties do
      since_version "1.7.0"
      description "Recommends using the escape heredoc start when escaping interpolation or other chars in a heredoc body"
    end

    MSG_ESCAPE_NEEDED     = "Use an escaped heredoc"
    MSG_ESCAPE_NOT_NEEDED = "Unnecessary heredoc escape"

    def test(source, node : Crystal::StringInterpolation)
      return unless start_location = node.location

      start_location_pos = source.pos(start_location)
      return unless source.code[start_location_pos..(start_location_pos + 2)]? == "<<-"

      # Heredocs without interpolation are always size 1
      return unless node.expressions.size == 1
      return unless expr = node.expressions.first?.try(&.as?(Crystal::StringLiteral))

      if source.code[start_location_pos + 3]? == '\''
        if expr.value.includes?("\#{") || has_escape_sequence?(expr.value)
          return
        end

        issue_for node, MSG_ESCAPE_NOT_NEEDED
      else
        if !(expr.value.includes?("\#{") || has_escape_sequence?(expr.value))
          return
        end

        issue_for node, MSG_ESCAPE_NEEDED
      end
    end

    def has_escape_sequence?(value : String)
      value.matches?(/(?<!\\)\\(?:\\|a|b|n|r|t|v|f|e|x|u|[0-7]|\n|\r)/)
    end
  end
end
