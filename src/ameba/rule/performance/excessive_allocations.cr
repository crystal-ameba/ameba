require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify excessive collection allocations,
  # that can be avoided by using `each_<member>` instead of `<collection>.each`.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # "Alice".chars.each { |c| puts c }
  # "Alice\nBob".lines.each { |l| puts l }
  # ```
  #
  # And can be written as this:
  #
  # ```
  # "Alice".each_char { |c| puts c }
  # "Alice\nBob".each_line { |l| puts l }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/ExcessiveAllocations:
  #   Enabled: true
  #   CallNames:
  #     codepoints: each_codepoint
  #     graphemes: each_grapheme
  #     chars: each_char
  #     lines: each_line
  # ```
  class ExcessiveAllocations < Base
    include AST::Util

    properties do
      description "Identifies usage of excessive collection allocations"
      call_names({
        "codepoints" => "each_codepoint",
        "graphemes"  => "each_grapheme",
        "chars"      => "each_char",
        "lines"      => "each_line",
        # "keys"       => "each_key",
        # "values"     => "each_value",
        # "children"   => "each_child",
      })
    end

    MSG = "Use `%s {...}` instead of `%s.each {...}` to avoid excessive allocation"

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "each" && node.args.empty?
      return unless (obj = node.obj).is_a?(Crystal::Call)
      return unless obj.args.empty? && obj.block.nil?
      return unless method = call_names[obj.name]?

      return unless name_location = name_location(obj)
      return unless end_location = name_end_location(node)

      msg = MSG % {method, obj.name}

      issue_for name_location, end_location, msg do |corrector|
        corrector.replace(name_location, end_location, method)
      end
    end
  end
end
