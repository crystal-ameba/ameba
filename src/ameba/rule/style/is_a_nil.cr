module Ameba::Rule::Style
  # A rule that disallows calls to `is_a?(Nil)` in favor of `nil?`.
  #
  # This is considered bad:
  #
  # ```
  # var.is_a?(Nil)
  # ```
  #
  # And needs to be written as:
  #
  # ```
  # var.nil?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/IsANil:
  #   Enabled: true
  # ```
  class IsANil < Base
    include AST::Util

    properties do
      since_version "0.13.0"
      description "Disallows calls to `is_a?(Nil)` in favor of `nil?`"
    end

    MSG = "Use `nil?` instead of `is_a?(Nil)`"

    def test(source, node : Crystal::IsA)
      return if node.nil_check?

      const = node.const
      return unless path_named?(const, "Nil")

      if range = nil_check_range(source, node)
        issue_for(const, MSG) do |corrector|
          corrector.replace(range, implicit_self?(node.obj) ? "self.nil?" : "nil?")
        end
      else
        issue_for(const, MSG)
      end
    end

    # Returns the range spanning from the `is_a?` name to the end of the *node*.
    private def nil_check_range(source, node)
      return unless end_location = node.end_location

      end_pos = source.pos(end_location, end: true)
      return unless start_pos = source.code.rindex("is_a?", end_pos)

      start_pos...end_pos
    end

    # Receiver-less call, i.e. `is_a?(Nil)`
    private def implicit_self?(obj)
      obj.is_a?(Crystal::Var) && obj.name == "self" && !obj.end_location
    end
  end
end
