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
      return if has_block?(node)
      return unless node.name == "to_a" && (obj = node.obj)

      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name == "map" && (obj2 = obj.obj)

      return if !obj2.is_a?(Crystal::Call) || has_block?(obj2)
      return unless obj2.name == "times" && (obj3 = obj2.obj)

      return unless location = obj3.location
      return unless end_location = name_end_location(node)

      if corrected_code = corrected_code(source, obj3, obj)
        issue_for(location, end_location, MSG % obj3) do |corrector|
          corrector.replace(location, end_location, corrected_code)
        end
      else
        issue_for(location, end_location, MSG % obj3)
      end
    end

    private def corrected_code(source, count, map_call)
      return unless count_code = node_source(count, source.lines)
      return unless name_end_location = name_end_location(map_call)
      return unless end_location = map_call.end_location

      args_location = name_end_location.adjust(column_number: 1)
      return unless block_code = source_between(args_location, end_location, source.lines)

      block_code = block_code.strip
      block_code = block_code[1...-1].strip if block_code.starts_with?('(')

      if block_code.starts_with?('&')
        "Array.new(%s, %s)" % {count_code, block_code}
      else
        "Array.new(%s) %s" % {count_code, block_code}
      end
    end
  end
end
