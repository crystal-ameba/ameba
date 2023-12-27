module Ameba::Rule::Naming
  # A rule that makes sure that rescued exceptions variables are named as expected.
  #
  # For example, these are considered valid:
  #
  #     def foo
  #       # potentially raising computations
  #     rescue e
  #       Log.error(exception: e) { "Error" }
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
    properties do
      description "Makes sure that rescued exceptions variables are named as expected"
      allowed_names %w[e ex exception error]
    end

    MSG          = "Disallowed variable name, use one of these instead: '%s'"
    MSG_SINGULAR = "Disallowed variable name, use '%s' instead"

    def test(source, node : Crystal::ExceptionHandler)
      node.rescues.try &.each do |rescue_node|
        next if valid_name?(rescue_node.name)

        message =
          allowed_names.size == 1 ? MSG_SINGULAR : MSG

        issue_for rescue_node, message % allowed_names.join("', '")
      end
    end

    private def valid_name?(name)
      !name || name.in?(allowed_names)
    end
  end
end
