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

    def test(source, node : Crystal::Call)
      return unless chain = times_map_chain(node)

      count, map_call = chain
      return unless location = count.location
      return unless end_location = node.end_location

      count_code = code_between(source, location, count.end_location)
      block_arg = block_arg?(source, map_call)

      message = (block_arg ? MSG_BLOCK_ARG : MSG) % single_line(count, count_code)

      if count_code && (block_code = block_code(source, count, map_call, end_location))
        corrected_code =
          if block_arg
            "Array.new(%s, %s)" % {count_code, block_code}
          else
            "Array.new(%s) %s" % {count_code, block_code}
          end

        issue_for(location, end_location, message) do |corrector|
          corrector.replace(location, end_location, corrected_code)
        end
      else
        issue_for(location, end_location, message)
      end
    end

    # Returns the count expression and the `map` call
    # of a `count.times.map { ... }.to_a` call chain.
    private def times_map_chain(node) : {Crystal::ASTNode, Crystal::Call}?
      return unless node.name == "to_a" && plain_call?(node)
      return unless (map_call = node.obj).is_a?(Crystal::Call)
      return unless map_call.name == "map" && has_block?(map_call)
      return if has_arguments?(map_call)
      return unless (times_call = map_call.obj).is_a?(Crystal::Call)
      return unless times_call.name == "times" && plain_call?(times_call)
      return unless count = times_call.obj

      {count, map_call}
    end

    # Returns `true` if the call has neither arguments nor a block.
    private def plain_call?(node)
      !has_block?(node) && !has_arguments?(node)
    end

    # Returns the original code of the `map` block, or `nil`
    # if moving it would lose the comments around it.
    private def block_code(source, count, map_call, end_location) : String?
      return unless count_end_location = count.end_location
      return unless block = map_call.block_arg || map_call.block
      return unless block_location = block.location
      # short blocks (`&.foo`) have no end location of their own
      return unless block_end_location =
                      block.end_location ||
                      block.as?(Crystal::Block).try(&.body.end_location)

      count_end_pos = source.pos(count_end_location, end: true)
      block_range = source.pos(block_location)...source.pos(block_end_location, end: true)
      end_pos = source.pos(end_location, end: true)

      # the code around the block holds no literals (only `.times.map(`,
      # `).to_a` and alike), so any `#` found there starts a comment
      return if source.code[count_end_pos...block_range.begin].includes?('#') ||
                source.code[block_range.end...end_pos].includes?('#')

      code = source.code[block_range]
      map_call.block_arg ? "&#{code}" : code
    end

    # Returns `true` if the block is passed as an argument
    # (`&block`) or using the short block syntax (`&.foo`).
    private def block_arg?(source, map_call) : Bool
      return true if map_call.block_arg
      return false unless location = map_call.block.try(&.location)

      source.code[source.pos(location)]? == '&'
    end

    # Returns the original code between *location* and *end_location* (inclusive),
    # slicing it from the source keeps its line endings intact.
    private def code_between(source, location, end_location) : String?
      return unless location && end_location

      source.code[source.pos(location)...source.pos(end_location, end: true)]?
    end

    # Keeps the issue message on a single line.
    private def single_line(node, code)
      return code if code && !code.includes?('\n')

      node.to_s
        .gsub(/\s*\n\s*(?=\.)/, "")
        .gsub(/\s*\n\s*/, " ")
    end
  end
end
