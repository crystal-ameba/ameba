# Utility module for Ameba's rules.
module Ameba::AST::Util
  extend self

  # Returns tuple with two bool flags:
  #
  # 1. is *node* a literal?
  # 2. can *node* be proven static?
  protected def literal_kind?(node) : {Bool, Bool}
    case node
    when Crystal::NilLiteral,
         Crystal::BoolLiteral,
         Crystal::NumberLiteral,
         Crystal::CharLiteral,
         Crystal::StringLiteral,
         Crystal::SymbolLiteral,
         Crystal::ProcLiteral,
         Crystal::MacroLiteral
      {true, true}
    when Crystal::StringInterpolation
      {true, node.expressions.all? do |exp|
        static_literal?(exp)
      end}
    when Crystal::RegexLiteral
      {true, static_literal?(node.value)}
    when Crystal::RangeLiteral
      {true, static_literal?(node.from) &&
        static_literal?(node.to)}
    when Crystal::ArrayLiteral,
         Crystal::TupleLiteral
      {true, node.elements.all? do |element|
        static_literal?(element)
      end}
    when Crystal::HashLiteral
      {true, node.entries.all? do |entry|
        static_literal?(entry.key) &&
          static_literal?(entry.value)
      end}
    when Crystal::NamedTupleLiteral
      {true, node.entries.all? do |entry|
        static_literal?(entry.value)
      end}
    else
      {false, false}
    end
  end

  # Returns `true` if current `node` is a static literal, `false` otherwise.
  def static_literal?(node) : Bool
    is_literal, is_static = literal_kind?(node)
    is_literal && is_static
  end

  # Returns `true` if current `node` is a dynamic literal, `false` otherwise.
  def dynamic_literal?(node) : Bool
    is_literal, is_static = literal_kind?(node)
    is_literal && !is_static
  end

  # Returns `true` if current `node` is a literal, `false` otherwise.
  def literal?(node) : Bool
    is_literal, _ = literal_kind?(node)
    is_literal
  end

  # Returns `true` if current `node` is a `Crystal::Path`
  # matching given *name*, `false` otherwise.
  def path_named?(node, *names : String) : Bool
    node.is_a?(Crystal::Path) &&
      node.names.join("::").in?(names)
  end

  # Returns `true` if the *node* is a `Crystal::Call`
  # with either `node.block` or `node.block_arg` set, `false` otherwise.
  def has_block?(node) : Bool
    node.is_a?(Crystal::Call) &&
      !!(node.block || node.block_arg)
  end

  # Returns `true` if the *node* is a `Crystal::Call`
  # with either `node.block` or `node.block_arg` set, `false` otherwise.
  def has_arguments?(node) : Bool
    node.is_a?(Crystal::Call) &&
      !!(node.args.present? || node.named_args.try(&.present?))
  end

  # Returns `true` if the *node* is a `Crystal::Def`
  # with either `args`, `splat_index`, or `double_splat` set,
  # `false` otherwise.
  def takes_arguments?(node) : Bool
    node.is_a?(Crystal::Def) &&
      !!(node.args.present? || node.splat_index || node.double_splat)
  end

  # Returns a source code for the current node.
  # This method uses `node.location` and `node.end_location`
  # to determine and cut a piece of source of the node.
  def node_source(node, code_lines)
    loc, end_loc = node.location, node.end_location
    return unless loc && end_loc

    source_between(loc, end_loc, code_lines)
  end

  # Returns the source code from *loc* to *end_loc* (inclusive).
  def source_between(loc, end_loc, code_lines) : String?
    line, column = loc.line_number - 1, loc.column_number - 1
    end_line, end_column = end_loc.line_number - 1, end_loc.column_number - 1
    node_lines = code_lines[line..end_line]
    first_line, last_line = node_lines[0]?, node_lines[-1]?

    return if first_line.nil? || last_line.nil?
    return if first_line.size < column # compiler reports incorrect location

    node_lines[0] = first_line.sub(0...column, "")

    if line == end_line # one line
      end_column = end_column - column
      last_line = node_lines[0]
    end

    return if last_line.size < end_column + 1

    node_lines[-1] = last_line.sub(end_column + 1...last_line.size, "")
    node_lines.join('\n')
  end

  # Returns `true` if node is a flow command, `false` otherwise.
  # Node represents a flow command if it is a control expression,
  # or special call node that interrupts execution (i.e. raise, exit, abort).
  def flow_command?(node, in_loop)
    case node
    when Crystal::Return
      true
    when Crystal::Break, Crystal::Next
      in_loop
    when Crystal::Call
      raise?(node) || exit?(node) || abort?(node)
    else
      false
    end
  end

  # Returns `true` if node is a flow expression, `false` if not.
  # Node represents a flow expression if it is full-filled by a flow command.
  #
  # For example, this node is a flow expression, because each branch contains
  # a flow command `return`:
  #
  # ```
  # if a > 0
  #   return :positive
  # elsif a < 0
  #   return :negative
  # else
  #   return :zero
  # end
  # ```
  #
  # This node is a not a flow expression:
  #
  # ```
  # if a > 0
  #   return :positive
  # end
  # ```
  #
  # That's because not all branches return(i.e. `else` is missing).
  def flow_expression?(node, in_loop = false)
    return true if flow_command? node, in_loop

    case node
    when Crystal::If, Crystal::Unless
      flow_expressions? [node.then, node.else], in_loop
    when Crystal::BinaryOp
      flow_expression? node.left, in_loop
    when Crystal::Case, Crystal::Select
      flow_expressions? [node.whens, node.else].flatten, in_loop
    when Crystal::ExceptionHandler
      flow_expressions? [node.else || node.body, node.rescues].flatten, in_loop
    when Crystal::While, Crystal::Until, Crystal::Rescue, Crystal::When
      flow_expression? node.body, in_loop
    when Crystal::Expressions
      node.expressions.any? { |exp| flow_expression? exp, in_loop }
    else
      false
    end
  end

  private def flow_expressions?(nodes, in_loop)
    nodes.all? { |exp| flow_expression? exp, in_loop }
  end

  # Returns `true` if node represents `raise` method call.
  def raise?(node)
    node.is_a?(Crystal::Call) &&
      node.name == "raise" && node.args.size == 1 && node.obj.nil?
  end

  # Returns `true` if node represents `exit` method call.
  def exit?(node)
    node.is_a?(Crystal::Call) &&
      node.name == "exit" && node.args.size <= 1 && node.obj.nil?
  end

  # Returns `true` if node represents `abort` method call.
  def abort?(node)
    node.is_a?(Crystal::Call) &&
      node.name == "abort" && node.args.size <= 2 && node.obj.nil?
  end

  # Returns `true` if node represents a loop.
  def loop?(node)
    case node
    when Crystal::While, Crystal::Until
      true
    when Crystal::Call
      node.name == "loop" && node.args.empty? && node.obj.nil?
    else
      false
    end
  end

  # Returns `true` if *name* represents operator method.
  def operator_method_name?(name : String)
    name != "->" &&
      name.chars.none?(&.alphanumeric?)
  end

  # Returns `true` if *node* represents operator method.
  def operator_method?(node)
    return false unless node.responds_to?(:name)
    return false unless name = node.name.try(&.to_s.presence)

    operator_method_name?(name)
  end

  # Returns `true` if *node* is a suffix node (`if` / `unless` / `rescue` / `ensure`).
  def suffix?(node)
    case node
    when Crystal::If, Crystal::Unless
      node.location == node.then.location
    when Crystal::ExceptionHandler
      node.suffix
    else
      false
    end
  end

  # Returns `true` if node has a `:nodoc:` annotation as the first line.
  def nodoc?(node)
    return false unless node.responds_to?(:doc)
    return false unless doc = node.doc.presence

    doc.lines.first?.try(&.strip) == ":nodoc:"
  end

  # Returns `true` if node is a _heredoc_, `false` otherwise.
  def heredoc?(node, source : Source)
    return false unless node.is_a?(Crystal::StringInterpolation) ||
                        node.is_a?(Crystal::StringLiteral)
    return false unless location = node.location
    return false unless location_pos = source.pos(location)

    source.code[location_pos..(location_pos + 2)]? == "<<-"
  end

  # Returns the exp code of a control expression.
  # Wraps implicit tuple literal with curly brackets (e.g. multi-return).
  def control_exp_code(node : Crystal::ControlExpression, code_lines)
    return unless exp = node.exp
    return unless exp_code = node_source(exp, code_lines)
    return exp_code unless exp.is_a?(Crystal::TupleLiteral) && exp_code[0] != '{'
    return unless exp_start = exp.elements.first.location
    return unless exp_end = exp.end_location

    "{#{source_between(exp_start, exp_end, code_lines)}}"
  end

  def name_location_or(node : Crystal::ASTNode, *, adjust_location_column_number = nil)
    name = node.name if node.responds_to?(:name)

    return node unless name = name.try(&.to_s.presence)
    return node unless location = name_location(node) || node.location

    location =
      location.adjust(column_number: adjust_location_column_number || 0)

    end_location =
      location.adjust(column_number: name.size - 1)

    {location, end_location}
  end

  def name_location_or(token : Crystal::Token, name, *, adjust_location_column_number = nil)
    name = name.to_s.presence

    location =
      token.location.adjust(column_number: adjust_location_column_number || 0)

    end_location =
      location.adjust(column_number: name ? name.size - 1 : 0)

    {location, end_location}
  end

  # Returns `nil` if *node* does not contain a name.
  def name_location(node)
    if loc = node.name_location
      return loc
    end

    return node.var.location if node.is_a?(Crystal::TypeDeclaration) ||
                                node.is_a?(Crystal::UninitializedVar)
    return unless node.responds_to?(:name) && (name = node.name)
    return unless name.is_a?(Crystal::ASTNode)

    name.location
  end

  # Returns zero if *node* does not contain a name.
  def name_size(node)
    unless (size = node.name_size).zero?
      return size
    end

    return 0 unless node.responds_to?(:name) && (name = node.name)

    case name
    when Crystal::ASTNode     then name.name_size
    when Crystal::Token::Kind then name.to_s.size # Crystal::MagicConstant
    else                           name.size
    end
  end

  # Returns `nil` if *node* does not contain a name.
  #
  # NOTE: Use this instead of `Crystal::Call#name_end_location` to avoid an
  #       off-by-one error.
  def name_end_location(node)
    return unless loc = name_location(node)
    return if (size = name_size(node)).zero?

    loc.adjust(column_number: size - 1)
  end
end
