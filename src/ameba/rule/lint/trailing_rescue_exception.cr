module Ameba::Rule::Lint
  # A rule that prohibits the common misconception about trailing rescue statements,
  # preventing the use of Paths (exception class names or otherwise) from being
  # used as the trailing value.
  #
  # For example, this is considered invalid:
  #
  # ```
  # value = method.call("param") rescue MyException
  # ```
  #
  # And should instead be written as:
  #
  # ```
  # value = begin
  #   method.call("param")
  # rescue MyException
  #   "default value"
  # end
  # ```
  #
  # Or to rescue all exceptions (instead of just `MyException`):
  #
  # ```
  # value = method.call("param") rescue "default value"
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/TrailingRescueException:
  #   Enabled: true
  # ```
  class TrailingRescueException < Base
    properties do
      description "Disallows trailing rescue with a path"
    end

    MSG = "Trailing rescues with a path aren't allowed, use a block rescue instead to filter by exception type"

    def test(source, node : Crystal::ExceptionHandler)
      return unless node.suffix &&
                    (rescues = node.rescues) &&
                    (resc = rescues.first?) &&
                    resc.body.is_a?(Crystal::Path)

      issue_for resc.body, MSG, prefer_name_location: true
    end
  end
end
