module Ameba::Rule::Naming
  # A rule that makes sure that rescued exceptions variables are named as expected.
  #
  # For example, these are considered valid:
  #
  #     def foo
  #       # potentially raising computations
  #     rescue ex
  #       Log.error(exception: ex) { "Error" }
  #     end
  #
  # And these are invalid variable names:
  #
  #     def foo
  #       # potentially raising computations
  #     rescue wtf
  #       Log.error(exception: wtf) { "Error" }
  #     end
  #
  # YAML configuration example:
  #
  # ```
  # Naming/RescuedExceptionsVariableName:
  #   Enabled: true
  #   AllowedNames: [e, ex, exception, error]
  # ```
  class RescuedExceptionsVariableName < Base
    include AST::Util

    properties do
      since_version "1.6.0"
      description "Makes sure that rescued exceptions variables are named as expected"
      allowed_names %w[e ex exception error]
    end

    MSG          = "Disallowed variable name, use one of these instead: %s"
    MSG_SINGULAR = "Disallowed variable name, use %s instead"

    def test(source, node : Crystal::Rescue)
      return unless name = node.name
      return if name.in?(allowed_names)

      message =
        allowed_names.size == 1 ? MSG_SINGULAR : MSG

      issue_for name_location_or(node, adjust_location_column_number: {{ "rescue ".size }}),
        message % allowed_names.map { |val| "`#{val}`" }.join(", ")
    end
  end
end
