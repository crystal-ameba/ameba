module Ameba::Rule::Lint
  # This rule is used to identify usage of `index/rindex/find/match` calls
  # followed by a call to `not_nil!`.
  #
  # For example, this is considered a code smell:
  #
  # ```
  # %w[Alice Bob].find(&.chars.any?(&.in?('o', 'b'))).not_nil!
  # ```
  #
  # And can be written as this:
  #
  # ```
  # %w[Alice Bob].find!(&.chars.any?(&.in?('o', 'b')))
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/NotNilAfterNoBang:
  #   Enabled: true
  # ```
  class NotNilAfterNoBang < Base
    include AST::Util

    properties do
      description "Identifies usage of `index/rindex/find/match` calls followed by `not_nil!`"
    end

    MSG = "Use `%s! {...}` instead of `%s {...}.not_nil!`"

    BLOCK_CALL_NAMES = %w[index rindex find]
    CALL_NAMES       = %w[index rindex match]

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "not_nil!" && node.args.empty?
      return unless (obj = node.obj).is_a?(Crystal::Call)
      return unless obj.name.in?(obj.block ? BLOCK_CALL_NAMES : CALL_NAMES)

      return unless name_location = name_location(obj)
      return unless name_location_end = name_end_location(obj)
      return unless end_location = name_end_location(node)

      msg = MSG % {obj.name, obj.name}

      issue_for name_location, end_location, msg do |corrector|
        corrector.insert_after(name_location_end, '!')
        corrector.remove_trailing(node, {{ ".not_nil!".size }})
      end
    end
  end
end
