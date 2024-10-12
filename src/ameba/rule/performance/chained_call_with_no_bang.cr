require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of chained calls not utilizing
  # the bang method variants.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # names = %w[Alice Bob]
  # chars = names
  #   .flat_map(&.chars)
  #   .uniq
  #   .sort
  # ```
  #
  # And can be written as this:
  #
  # ```
  # names = %w[Alice Bob]
  # chars = names
  #   .flat_map(&.chars)
  #   .uniq!
  #   .sort!
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/ChainedCallWithNoBang:
  #   Enabled: true
  #   CallNames:
  #     - uniq
  #     - sort
  #     - sort_by
  #     - shuffle
  #     - reverse
  # ```
  class ChainedCallWithNoBang < Base
    include AST::Util

    properties do
      description "Identifies usage of chained calls not utilizing the bang method variants"

      # All of those have bang method variants returning `self`
      # and are not modifying the receiver type (like `compact` does),
      # thus are safe to switch to the bang variant.
      call_names %w[uniq sort sort_by shuffle reverse]
    end

    MSG = "Use bang method variant `%s!` after chained `%s` call"

    # All these methods allocate a new object
    ALLOCATING_METHOD_NAMES = %w[
      keys values values_at map map_with_index flat_map compact_map
      flatten compact select reject sample group_by chunks tally merge
      combinations repeated_combinations permutations repeated_permutations
      transpose invert split chars lines captures named_captures clone
    ]

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless (obj = node.obj).is_a?(Crystal::Call)
      return unless node.name.in?(call_names)
      return unless obj.name.in?(call_names) || obj.name.in?(ALLOCATING_METHOD_NAMES)

      if end_location = name_end_location(node)
        issue_for node, MSG % {node.name, obj.name}, prefer_name_location: true do |corrector|
          corrector.insert_after(end_location, '!')
        end
      else
        issue_for node, MSG % {node.name, obj.name}, prefer_name_location: true
      end
    end
  end
end
