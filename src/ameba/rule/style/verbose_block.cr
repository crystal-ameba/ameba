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
  #   ExcludeCallsWithBlocks: true
  #   ExcludePrefixOperators: true
  #   ExcludeOperators: true
  #   ExcludeSetters: false
  #   MaxLineLength: ~
  #   MaxLength: 50 # use ~ to disable
  # ```
  class VerboseBlock < Base
    properties do
      description "Identifies usage of collapsible single expression blocks."

      exclude_multiple_line_blocks true
      exclude_calls_with_block true
      exclude_prefix_operators true
      exclude_operators true
      exclude_setters false

      max_line_length : Int32? = nil # 100
      max_length : Int32? = 50
    end

    MSG          = "Use short block notation instead: `%s`"
    CALL_PATTERN = "%s(%s&.%s)"

    protected def same_location_lines?(a, b)
      return unless a_location = a.name_location
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
      name.each_char do |char|
        return false unless char.in?(OPERATOR_CHARS)
      end
      !name.empty?
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
        if location = node.name_location
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
      when Crystal::Block
        i += reference_count(node.body, obj)
      when Crystal::Var
        i += 1 if node == obj
      end
      i
    end

    protected def args_to_s(io : IO, node : Crystal::Call, skip_last_arg = false)
      node.args.dup.tap do |args|
        args.pop? if skip_last_arg
        args.join io, ", "
        node.named_args.try do |named_args|
          io << ", " unless args.empty? || named_args.empty?
          named_args.join io, ", " do |arg, inner_io|
            inner_io << arg.name << ": " << arg.value
          end
        end
      end
    end

    protected def node_to_s(node : Crystal::Call)
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
          str << name
          if !node.args.empty? || (node.named_args && !node.named_args.try(&.empty?))
            str << '('
            args_to_s(str, node)
            str << ')'
          end
          str << " {...}" if node.block
        end
      end
    end

    protected def call_code(call, body)
      args = String.build { |io| args_to_s(io, call) }.presence
      args += ", " if args

      call_chain = %w[].tap do |arr|
        obj = body.obj
        while obj.is_a?(Crystal::Call)
          arr << node_to_s(obj)
          obj = obj.obj
        end
        arr.reverse!
        arr << node_to_s(body)
      end

      name =
        call_chain.join('.')

      CALL_PATTERN % {call.name, args, name}
    end

    # ameba:disable Metrics/CyclomaticComplexity
    protected def issue_for_valid(source, call : Crystal::Call, body : Crystal::Call)
      return if exclude_calls_with_block && body.block
      return if exclude_multiple_line_blocks && !same_location_lines?(call, body)
      return if exclude_prefix_operators && prefix_operator?(body)
      return if exclude_operators && operator?(body.name)
      return if exclude_setters && setter?(body.name)

      call_code =
        call_code(call, body)

      return unless valid_line_length?(call, call_code)
      return unless valid_length?(call_code)

      issue_for call.name_location, call.end_location,
        MSG % call_code
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

      # we skip auto-generated blocks - `(1..3).any?(&.odd?)`
      return if arg.name.starts_with?("__arg")

      # we filter out the blocks that are of call type - `i.to_i64.odd?`
      return unless (body = block.body).is_a?(Crystal::Call)

      # we need to "unwind" the chain challs, so the final receiver object
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
      issue_for_valid source, node, body
    end
  end
end
