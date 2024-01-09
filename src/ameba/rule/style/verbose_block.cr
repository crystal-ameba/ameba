module Ameba::Rule::Style
  # This rule is used to identify usage of single expression blocks with
  # argument as a receiver, that can be collapsed into a short form.
  #
  # For example, this is considered invalid:
  #
  # ```
  # (1..3).any? { |i| i.odd? }
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # (1..3).any?(&.odd?)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/VerboseBlock:
  #   Enabled: true
  #   ExcludeMultipleLineBlocks: true
  #   ExcludeCallsWithBlock: true
  #   ExcludePrefixOperators: true
  #   ExcludeOperators: true
  #   ExcludeSetters: false
  #   MaxLineLength: ~
  #   MaxLength: 50 # use ~ to disable
  # ```
  class VerboseBlock < Base
    include AST::Util

    properties do
      description "Identifies usage of collapsible single expression blocks"

      exclude_multiple_line_blocks true
      exclude_calls_with_block true
      exclude_prefix_operators true
      exclude_operators true
      exclude_setters false

      max_line_length nil, as: Int32?
      max_length 50, as: Int32?
    end

    MSG          = "Use short block notation instead: `%s`"
    CALL_PATTERN = "%s(%s&.%s)"

    protected def same_location_lines?(a, b)
      return unless a_location = name_location(a)
      return unless b_location = b.location

      a_location.line_number == b_location.line_number
    end

    private PREFIX_OPERATORS = {"+", "-", "~"}
    private OPERATOR_CHARS   =
      {'[', ']', '!', '=', '>', '<', '~', '+', '-', '*', '/', '%', '^', '|', '&'}

    protected def prefix_operator?(node)
      node.name.in?(PREFIX_OPERATORS) && node.args.empty?
    end

    protected def operator?(name)
      !name.empty? && name[0].in?(OPERATOR_CHARS)
    end

    protected def setter?(name)
      !name.empty? && name[0].letter? && name.ends_with?('=')
    end

    protected def valid_length?(code)
      if max_length = self.max_length
        return code.size <= max_length
      end
      true
    end

    protected def valid_line_length?(node, code)
      if max_line_length = self.max_line_length
        if location = name_location(node)
          final_line_length = location.column_number + code.size
          return final_line_length <= max_line_length
        end
      end
      true
    end

    protected def reference_count(node, obj : Crystal::Var)
      i = 0
      case node
      when Crystal::Call
        i += reference_count(node.obj, obj)
        i += reference_count(node.block, obj)

        node.args.each do |arg|
          i += reference_count(arg, obj)
        end
        node.named_args.try &.each do |arg|
          i += reference_count(arg.value, obj)
        end
      when Crystal::BinaryOp
        i += reference_count(node.left, obj)
        i += reference_count(node.right, obj)
      when Crystal::Block
        i += reference_count(node.body, obj)
      when Crystal::Var
        i += 1 if node == obj
      end
      i
    end

    protected def args_to_s(io : IO, node : Crystal::Call, short_block = nil, skip_last_arg = false) : Nil
      args = node.args.dup
      args.pop? if skip_last_arg
      args.join io, ", "

      named_args = node.named_args
      if named_args
        io << ", " unless args.empty? || named_args.empty?
        named_args.join io, ", " do |arg, inner_io|
          inner_io << arg.name << ": " << arg.value
        end
      end

      if short_block
        io << ", " unless args.empty? && (named_args.nil? || named_args.empty?)
        io << short_block
      end
    end

    protected def node_to_s(source, node : Crystal::Call)
      String.build do |str|
        case name = node.name
        when "[]"
          str << '['
          args_to_s(str, node)
          str << ']'
        when "[]?"
          str << '['
          args_to_s(str, node)
          str << "]?"
        when "[]="
          str << '['
          args_to_s(str, node, skip_last_arg: true)
          str << "]=(" << node.args.last? << ')'
        else
          short_block = short_block_code(source, node)
          str << name
          if !node.args.empty? || (node.named_args && !node.named_args.try(&.empty?)) || short_block
            str << '('
            args_to_s(str, node, short_block)
            str << ')'
          end
          str << " {...}" if node.block && short_block.nil?
        end
      end
    end

    protected def short_block_code(source, node : Crystal::Call)
      return unless block = node.block
      return unless block_location = block.location
      return unless block_end_location = block.body.end_location

      block_code = source_between(block_location, block_end_location, source.lines)
      block_code if block_code.try(&.starts_with?("&."))
    end

    protected def call_code(source, call, body)
      args = String.build { |io| args_to_s(io, call) }.presence
      args += ", " if args

      call_chain = %w[].tap do |arr|
        obj = body.obj
        while obj.is_a?(Crystal::Call)
          arr << node_to_s(source, obj)
          obj = obj.obj
        end
        arr.reverse!
        arr << node_to_s(source, body)
      end

      name =
        call_chain.join('.')

      CALL_PATTERN % {call.name, args, name}
    end

    # ameba:disable Metrics/CyclomaticComplexity
    protected def issue_for_valid(source, call : Crystal::Call, block : Crystal::Block, body : Crystal::Call)
      return if exclude_calls_with_block? && body.block
      return if exclude_multiple_line_blocks? && !same_location_lines?(call, body)
      return if exclude_prefix_operators? && prefix_operator?(body)
      return if exclude_operators? && operator?(body.name)
      return if exclude_setters? && setter?(body.name)

      call_code =
        call_code(source, call, body)

      return unless valid_line_length?(call, call_code)
      return unless valid_length?(call_code)

      return unless location = name_location(call)
      return unless end_location = block.end_location

      if call_code.includes?("{...}")
        issue_for location, end_location, MSG % call_code
      else
        issue_for location, end_location, MSG % call_code do |corrector|
          corrector.replace(location, end_location, call_code)
        end
      end
    end

    def test(source, node : Crystal::Call)
      # we are interested only in calls with block taking a single argument
      #
      # ```
      # (1..3).any? { |i| i.to_i64.odd? }
      #        ^---    ^  ^------------
      #        block  arg  body
      # ```
      return unless (block = node.block) && block.args.size == 1

      arg = block.args.first

      # we filter out the blocks that are of call type - `i.to_i64.odd?`
      return unless (body = block.body).is_a?(Crystal::Call)

      # we need to "unwind" the call chain, so the final receiver object
      # ends up being a variable - `i`
      obj = body.obj
      while obj.is_a?(Crystal::Call)
        obj = obj.obj
      end

      # only calls with a first argument used as a receiver are the valid game
      return unless obj == arg

      # we bail out if the block node include the block argument
      return if reference_count(body, arg) > 1

      # add issue if the given nodes pass all of the checks
      issue_for_valid source, node, block, body
    end
  end
end
