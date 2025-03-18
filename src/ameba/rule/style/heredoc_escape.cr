module Ameba::Rule::Style
  # A rule that enforces heredoc variant that escapes interpolation or control
  # chars in a heredoc body. The opposite is enforced too - i.e. regular heredoc
  # variant that doesn't escape interpolation or control chars in a heredoc body,
  # when there is no need to escape it.
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
      description "Recommends using the heredoc variant that escapes interpolation or control chars in a heredoc body"
    end

    MSG_ESCAPE_NEEDED     = "Use an escaped heredoc marker: `<<-'%s'`"
    MSG_ESCAPE_NOT_NEEDED = "Use an unescaped heredoc marker: `<<-%s`"

    ESCAPE_SEQUENCE_PATTERN =
      /\\(?:[abefnrtv]|[0-7]{1,3}|x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|u\{[0-9a-fA-F]{1,6}\})/

    def test(source, node : Crystal::StringInterpolation)
      # Heredocs without interpolations have always size of 1
      return unless node.expressions.size == 1
      return unless expr = node.expressions.first.as?(Crystal::StringLiteral)

      return unless code = node_source(node, source.lines)
      return unless code.starts_with?("<<-")

      body = code.lines[1..-2].join('\n')

      if code.starts_with?("<<-'")
        return if has_escape_sequence?(expr.value) || has_escaped_escape_sequence?(body)

        marker = code.lchop("<<-'").match!(/^(\w+)/)[1]
        msg = MSG_ESCAPE_NOT_NEEDED % marker
      else
        return if !has_escape_sequence?(expr.value) || has_escape_sequence?(body)

        marker = code.lchop("<<-").match!(/^(\w+)/)[1]
        msg = MSG_ESCAPE_NEEDED % marker
      end

      issue_for node, msg
    end

    private def has_escape_sequence?(value : String)
      value.matches? /(?<!\\)(?:#\{|#{ESCAPE_SEQUENCE_PATTERN})/,
        options: :no_utf_check
    end

    private def has_escaped_escape_sequence?(value : String)
      value.matches? /(?<!\\)(?:\\)+(?:#\{|#{ESCAPE_SEQUENCE_PATTERN})/,
        options: :no_utf_check
    end
  end
end
