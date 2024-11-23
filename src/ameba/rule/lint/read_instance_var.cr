module Ameba::Rule::Lint
  # A rule that disallows reading instance variables externally from an object
  # via the `object.@ivar` syntax.
  #
  # For example, this is not allowed:
  #
  # ```
  # class Greeter
  #   def combine(other : self)
  #     @ivar <=> other.@ivar
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ReadInstanceVar:
  #   Enabled: false
  # ```
  class ReadInstanceVar < Base
    properties do
      description "Disallows external reading of instance vars"
      enabled false
    end

    MSG = "Reading instance variables externally is not allowed."

    def test(source, node : Crystal::ReadInstanceVar)
      issue_for node, MSG
    end
  end
end
