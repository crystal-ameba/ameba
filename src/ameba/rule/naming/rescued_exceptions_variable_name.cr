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
      since_version "1.6.0"
      description "Makes sure that rescued exceptions variables are named as expected"
      allowed_names %w[e ex exception error]
    end

    MSG          = "Disallowed variable name, use one of these instead: `%s`"
    MSG_SINGULAR = "Disallowed variable name, use `%s` instead"

    def test(source, node : Crystal::ExceptionHandler)
      node.rescues.try &.each do |rescue_node|
        next unless name = rescue_node.name
        next if name.in?(allowed_names)

        message =
          allowed_names.size == 1 ? MSG_SINGULAR : MSG

        next unless location = rescue_node.location
        location =
          location.adjust(column_number: {{ "rescue ".size }})

        end_location =
          location.adjust(column_number: name.size - 1)

        issue_for location, end_location, message % allowed_names.join("`, `")
      end
    end
  end
end
