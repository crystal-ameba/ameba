module Ameba::Rule::Lint
  # This rule is used to identify usage of `index/find` calls followed by `not_nil!`.
  #
  # For example, this is considered a code smell:
  #
  # ```
  # %w[Alice Bob].find(&.match(/^A./)).not_nil!
  # ```
  #
  # And can be written as this:
  #
  # ```
  # %w[Alice Bob].find!(&.match(/^A./))
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
      description "Identifies usage of `index/find` calls followed by `not_nil!`"
    end

    BLOCK_CALL_NAMES = %w(index find)
    CALL_NAMES       = %w(index)

    NOT_NIL_NAME = "not_nil!"
    MSG          = "Use `%s! {...}` instead of `%s {...}.not_nil!`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroExpression,
        Crystal::MacroIf,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::Call)
      return unless node.name == NOT_NIL_NAME && node.args.empty?
      return unless (obj = node.obj).is_a?(Crystal::Call)
      return unless obj.name.in?(obj.block ? BLOCK_CALL_NAMES : CALL_NAMES)

      return unless name_location = obj.name_location
      return unless name_end_location = name_end_location(node)

      msg = MSG % {obj.name, obj.name}

      issue_for name_location, name_end_location, msg do |corrector|
        next unless location = node.location
        next unless end_location = node.end_location
        next unless name_location_end = name_end_location(obj)

        corrector.insert_after(name_location_end, '!')
        corrector.remove_trailing(location, end_location, {{ ".not_nil!".size }})
      end
    end
  end
end
