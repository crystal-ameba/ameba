require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `times.map { ... }.to_a` calls.
  #
  # For example, this is considered invalid:
  #
  # ```
  # 5.times.map { |i| i * 2 }.to_a
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # Array.new(5) { |i| i * 2 }
  # ```
  #
  # NOTE: These are not equivalent for negative counts, since `Int#times`
  # doesn't iterate over them, while `Array.new` raises `ArgumentError`:
  #
  # ```
  # -1.times.map { |i| i * 2 }.to_a # => []
  # Array.new(-1) { |i| i * 2 }     # raises ArgumentError
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/TimesMap:
  #   Enabled: true
  # ```
  class TimesMap < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Identifies usage of `times.map { ... }.to_a` calls"
    end

    MSG           = "Use `Array.new(%1$s) {...}` instead of `%1$s.times.map {...}.to_a`"
    MSG_BLOCK_ARG = "Use `Array.new(%1$s, &...)` instead of `%1$s.times.map(&...).to_a`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def test(source, node : Crystal::Call)
      return if has_block?(node) || has_arguments?(node)
      return unless node.name == "to_a" && (obj = node.obj)

      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return if has_arguments?(obj)
      return unless obj.name == "map" && (obj2 = obj.obj)

      return if !obj2.is_a?(Crystal::Call) || has_block?(obj2) || has_arguments?(obj2)
      return unless obj2.name == "times" && (obj3 = obj2.obj)

      return unless location = obj3.location
      return unless end_location = node.end_location

      count_code = code_between(source, location, obj3.end_location) || obj3.to_s
      message = (block_arg?(source, obj) ? MSG_BLOCK_ARG : MSG) % single_line(obj3, count_code)

      if corrected_code = corrected_code(source, obj3, obj, end_location)
        issue_for(location, end_location, message) do |corrector|
          corrector.replace(location, end_location, corrected_code)
        end
      else
        issue_for(location, end_location, message)
      end
    end

    private def corrected_code(source, count, map_call, end_location)
      return unless count_location = count.location
      return unless count_end_location = count.end_location
      return unless block = map_call.block_arg || map_call.block
      return unless block_location = block.location
      # short blocks (`&.foo`) have no end location of their own
      return unless block_end_location =
                      block.end_location ||
                      block.as?(Crystal::Block).try(&.body.end_location)

      # slicing the original code keeps its line endings intact
      count_range = source.pos(count_location)...source.pos(count_end_location, end: true)
      block_range = source.pos(block_location)...source.pos(block_end_location, end: true)
      end_pos = source.pos(end_location, end: true)

      # comments outside of the count and the block would be lost
      return if comments?(source.code[count_range.end...block_range.begin]) ||
                comments?(source.code[block_range.end...end_pos])

      count_code = source.code[count_range]
      block_code = source.code[block_range]

      block_code = "&#{block_code}" if map_call.block_arg

      if block_arg?(source, map_call)
        "Array.new(%s, %s)" % {count_code, block_code}
      else
        "Array.new(%s) %s" % {count_code, block_code}
      end
    end

    # Returns `true` if the block is passed as an argument
    # (`&block`) or using the short block syntax (`&.foo`).
    private def block_arg?(source, map_call) : Bool
      return true if map_call.block_arg
      return false unless location = map_call.block.try(&.location)

      source.code[source.pos(location)]? == '&'
    end

    # Returns the original code between *location* and *end_location* (inclusive).
    private def code_between(source, location, end_location) : String?
      return unless location && end_location

      source.code[source.pos(location)...source.pos(end_location, end: true)]?
    end

    # Keeps the issue message on a single line.
    private def single_line(node, code)
      return code unless code.includes?('\n')

      node.to_s
        .gsub(/\s*\n\s*(?=\.)/, "")
        .gsub(/\s*\n\s*/, " ")
    end

    private def comments?(code)
      lexer = Crystal::Lexer.new(code).tap(&.comments_enabled = true)
      comments = false

      Tokenizer.new(lexer).run do |token|
        comments = true if token.type.comment?
      end
      comments
    end
  end
end
