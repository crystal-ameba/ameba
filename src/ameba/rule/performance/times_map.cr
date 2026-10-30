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

    MSG = "Use `Array.new(%1$s) {...}` instead of `%1$s.times.map {...}.to_a`"

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

      count_code = node_source(obj3, source.lines) || obj3.to_s
      # keep the issue message on a single line
      message = MSG % (count_code.includes?('\n') ? obj3 : count_code)

      if corrected_code = corrected_code(source, location, end_location, count_code, obj)
        issue_for(location, end_location, message) do |corrector|
          corrector.replace(location, end_location, corrected_code)
        end
      else
        issue_for(location, end_location, message)
      end
    end

    private def corrected_code(source, location, end_location, count_code, map_call)
      return unless block = map_call.block_arg || map_call.block
      return unless block_location = block.location
      # short blocks (`&.foo`) have no end location of their own
      return unless block_end_location =
                      block.end_location ||
                      block.as?(Crystal::Block).try(&.body.end_location)

      # comments outside of the block would be lost
      return if comments_between?(location, block_location, source) ||
                comments_between?(block_end_location.adjust(column_number: 1), end_location, source)

      return unless block_code = source_between(block_location, block_end_location, source.lines)

      block_code = "&#{block_code}" if map_call.block_arg

      if block_code.starts_with?('&')
        "Array.new(%s, %s)" % {count_code, block_code}
      else
        "Array.new(%s) %s" % {count_code, block_code}
      end
    end

    private def comments_between?(location, end_location, source)
      return false unless code = source_between(location, end_location, source.lines)

      lexer = Crystal::Lexer.new(code).tap(&.comments_enabled = true)
      comments = false

      Tokenizer.new(lexer).run do |token|
        comments = true if token.type.comment?
      end
      comments
    end
  end
end
