# Helpers for correcting `return`, `break` and `next`.
module Ameba::AST::Util
  # Returns the arguments of `Corrector#replace` which remove the keyword of
  # a control expression, or `nil` if the correction wouldn't be safe.
  #
  # See `#control_exp_code` for the meaning of *operand*.
  def control_exp_replacement(node : Crystal::ControlExpression, code_lines, *, operand = false)
    return unless location = node.location
    return unless end_location = control_exp_end_location(node, code_lines)
    return unless code = control_exp_code(node, code_lines, operand: operand)

    {location, end_location, code}
  end

  # Returns the exp code of a control expression.
  # Wraps implicit tuple literal with curly brackets (e.g. multi-return).
  #
  # Arguments in parentheses (e.g. `return(1)`) keep them, unless they're
  # not needed to preserve the meaning of the code. Returns `nil` if the
  # closing parenthesis can't be found, or dropping it would drop a comment.
  #
  # Code which replaces an *operand* of an operator gets wrapped in
  # parentheses if needed, since `a || return b ? 1 : 2` differs from `a || b ? 1 : 2`.
  def control_exp_code(node : Crystal::ControlExpression, code_lines, *, operand = false)
    return unless exp = node.exp
    return unless exp_code = control_exp_value_code(exp, code_lines)
    return unless control_exp_replaceable?(node, code_lines)
    return exp_code if binds_tightly?(exp)
    return exp_code unless operand || control_exp_parenthesized?(node, code_lines)

    # The terminator of a heredoc has to stay on its own line
    "(#{exp_code})" unless exp_code.includes?("<<-")
  end

  private def control_exp_value_code(exp, code_lines)
    return unless exp_code = node_source(exp, code_lines)
    return exp_code unless exp.is_a?(Crystal::TupleLiteral) && exp_code[0] != '{'
    return unless exp_start = exp.elements.first.location
    return unless exp_end = exp.end_location

    "{#{source_between(exp_start, exp_end, code_lines)}}"
  end

  # Returns `true` if there is a comment between the
  # parentheses and the argument of a control expression.
  private def control_exp_comment?(node, exp, end_location, code_lines) : Bool
    location, exp_start, exp_end = node.location, exp.location, exp.end_location

    return true unless location && exp_start && exp_end

    {
      source_between(location, exp_start, code_lines),
      source_between(exp_end, end_location, code_lines),
    }.any? { |code| code.nil? || code.includes?('#') }
  end

  # Operators binding tighter than `&&` and `||`, and the rest of the
  # code which can surround a control expression being replaced.
  private TIGHT_BINDING_OPERATORS = %w[
    + - * / // % ** &+ &- &* &** << >> & | ^ == != === =~ !~ < <= > >= <=>
  ]

  # Returns `true` if *exp* means the same in place of a control expression.
  private def binds_tightly?(exp) : Bool
    case exp
    when Crystal::Call
      return false if exp.block || exp.block_arg
      return true if exp.has_parentheses? || (exp.args.empty? && !exp.named_args)

      exp.args.size == 1 && exp.name.in?(TIGHT_BINDING_OPERATORS)
    when Crystal::NilLiteral, Crystal::BoolLiteral, Crystal::NumberLiteral,
         Crystal::CharLiteral, Crystal::StringLiteral, Crystal::StringInterpolation,
         Crystal::SymbolLiteral, Crystal::RegexLiteral, Crystal::ArrayLiteral,
         Crystal::HashLiteral, Crystal::TupleLiteral, Crystal::NamedTupleLiteral,
         Crystal::Var, Crystal::InstanceVar, Crystal::ClassVar, Crystal::Global,
         Crystal::Path, Crystal::Expressions
      true
    else
      false
    end
  end

  # Returns `true` if the arguments of a control expression
  # are in parentheses directly following its keyword (e.g. `return(1)`).
  def control_exp_parenthesized?(node : Crystal::ControlExpression, code_lines) : Bool
    return false unless location = node.location
    return false unless line = code_lines[location.line_number - 1]?

    !!line[(location.column_number - 1)..]?.try(&.matches?(/\A\w+\(/))
  end

  # Returns `true` if a control expression with arguments can be replaced.
  #
  # If they're in parentheses, that requires finding the closing one, not
  # losing a comment, keeping heredocs intact, and not gluing the code to
  # what follows (e.g. `return(a)if b` to `aif b`).
  def control_exp_replaceable?(node : Crystal::ControlExpression, code_lines) : Bool
    return false unless exp = node.exp
    return true unless control_exp_parenthesized?(node, code_lines)
    return false unless end_location = control_exp_end_location(node, code_lines)
    return false if end_location == node.end_location

    # The terminator of a heredoc has to stay on its own line
    return false if node_source(exp, code_lines).try(&.includes?("<<-"))

    following_char = code_lines[end_location.line_number - 1]?.try(&.[end_location.column_number]?)
    return false if following_char.try(&.letter?)

    !control_exp_comment?(node, exp, end_location, code_lines)
  end

  # Returns the end location of a control expression, including the closing
  # parenthesis of `return(1)`, which `node.end_location` leaves out.
  #
  # Falls back to `node.end_location` if the parenthesis can't be found,
  # which is the case for heredocs (e.g. `return(<<-TEXT)`).
  def control_exp_end_location(node : Crystal::ControlExpression, code_lines) : Crystal::Location?
    return unless end_location = node.end_location
    return end_location unless control_exp_parenthesized?(node, code_lines)

    following_code =
      code_lines[(end_location.line_number - 1)..].join('\n')[end_location.column_number..]? || ""

    # An opening parenthesis follows the node when there are no arguments
    match = following_code.match(/\A\(?(?:\s|#[^\n]*)*,?(?:\s|#[^\n]*)*\)/)
    return end_location unless match

    closing_code = match[0]

    if newline_index = closing_code.rindex('\n')
      end_location.adjust(line_number: closing_code.count('\n'))
        .with(column_number: closing_code.size - newline_index - 1)
    else
      end_location.adjust(column_number: closing_code.size)
    end
  end
end
