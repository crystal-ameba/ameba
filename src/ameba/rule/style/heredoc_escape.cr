module Ameba::Rule::Style
  # A rule that enforces using an escaped heredoc to escape interpolation or escape sequences instead of backslashes.
  #
  # For example, this is considered invalid:
  #
  # ```
  # <<-DOC
  #   This is an escaped \#{:interpolated} string \\n
  #   DOC
  # ```
  #
  # And should be written as:
  #
  # ```
  # <<-'DOC'
  #   This is an escaped #{:interpolated} string \n
  #   DOC
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/HeredocEscape:
  #   Enabled: true
  # ```
  class HeredocEscape < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Recommends using the escape heredoc start when escaping interpolation or other chars in a heredoc body"
    end

    MSG_ESCAPE_NEEDED     = "Use an escaped heredoc marker: `<<-'%s'`"
    MSG_ESCAPE_NOT_NEEDED = "Use an unescaped heredoc marker: `<<-%s`"

    def test(source, node : Crystal::StringInterpolation)
      return unless (code = node_source(node, source.lines)) && code.starts_with?("<<-")
      # Heredocs without interpolation are always size 1
      return unless node.expressions.size == 1
      return unless expr = node.expressions.first?.as?(Crystal::StringLiteral)

      body = code.lines[1..-2].join('\n')

      if code.starts_with?("<<-'")
        return if has_escape_sequence?(expr.value) || has_escaped_escape_sequence?(body)

        marker = code.lines.first.lchop("<<-'").match!(/^(\w+)/)[1]

        issue_for node, MSG_ESCAPE_NOT_NEEDED % marker
      else
        return if !has_escape_sequence?(expr.value) || has_escape_sequence?(body)

        marker = code.lines.first.lchop("<<-").match!(/^(\w+)/)[1]

        issue_for node, MSG_ESCAPE_NEEDED % marker
      end
    end

    private def has_escape_sequence?(value : String)
      value.matches?(/(?<!\\)\#{/) || value.matches?(/(?<!\\)\\(?:[0-7abnrtvfexu\n])/)
    end

    private def has_escaped_escape_sequence?(value : String)
      value.matches?(/(?<!\\)(?:\\\\)*\\\#{/) || value.matches?(/(?<!\\)(?:\\\\)*\\\\(?:[0-7abnrtvfexu\n])/)
    end
  end
end
