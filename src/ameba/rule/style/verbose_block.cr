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
  #   ExcludeCallsWithBlocks: false
  #   ExcludeOperators: false
  #   ExcludeSetters: false
  #   MaxLineLength: ~
  #   MaxLength: 50 # use ~ to disable
  # ```
  class VerboseBlock < Base
    properties do
      description "Identifies usage of collapsible single expression blocks."

      exclude_calls_with_block true
      exclude_multiple_line_blocks false
      exclude_operators false
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

    private OPERATOR_CHARS =
      {'[', ']', '!', '=', '>', '<', '~', '+', '-', '*', '/', '%', '^', '|', '&'}

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

    protected def node_to_s(node : Crystal::Call)
      case name = node.name
      when "[]"
        name = "[#{node.args.join ", "}]"
      when "[]?"
        name = "[#{node.args.join ", "}]?"
      when "[]="
        unless node.args.empty?
          name = "[#{node.args[..-2].join ", "}]=(#{node.args.last})"
        end
      else
        name += "(#{node.args.join ", "})" unless node.args.empty?
        name += " {...}" if node.block
      end
      name
    end

    protected def call_code(call, body)
      args = call.args.join ", " unless call.args.empty?
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
    def test(source, node : Crystal::Call)
      # we are interested only in calls with block taking a single argument
      #
      # ```
      # (1..3).any? { |i| i.to_i64.odd? }
      #        ^---    ^  ^------------
      #        block  arg  body
      # ```
      return unless (block = node.block) && block.args.size == 1

      # we filter out the blocks that are of call type - `i.to_i64.odd?`
      return unless (body = block.body).is_a?(Crystal::Call)

      # we need to "unwind" the chain challs, so the final receiver object
      # ends up being a variable - `i`
      obj = body.obj
      while obj.is_a?(Crystal::Call)
        obj = obj.obj
      end
      return unless obj.is_a?(Crystal::Var)

      # only calls with a first argument used as a receiver are the valid game
      return unless (arg = block.args.first) == obj

      # we skip auto-generated blocks - `(1..3).any?(&.odd?)`
      return if arg.name.starts_with?("__arg")

      return if exclude_calls_with_block && body.block
      return if exclude_multiple_line_blocks && !same_location_lines?(node, body)
      return if exclude_operators && operator?(body.name)
      return if exclude_setters && setter?(body.name)

      call_code =
        call_code(node, body)

      return unless valid_line_length?(node, call_code)
      return unless valid_length?(call_code)

      issue_for node.name_location, node.end_location,
        MSG % call_code
    end
  end
end
