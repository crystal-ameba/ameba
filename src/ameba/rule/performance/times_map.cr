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
      AST::NodeVisitor.new self, source, skip: :macro
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

      issue_for location, end_location, MSG % obj3 do |corrector|
        corrected_code =
          case
          when block = obj.block
            block_code =
              node_source(block, source.lines)

            "Array.new(%s) %s" % {obj3, block_code}
          when block_arg = obj.block_arg
            "Array.new(%s, &%s)" % {obj3, block_arg}
          end
        next unless corrected_code

        corrector.replace(location, end_location, corrected_code)
      end
    end
  end
end
