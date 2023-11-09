module Ameba::Rule::Naming
  # A rule that enforces file names to be in underscored case.
  #
  # YAML configuration example:
  #
  # ```
  # Naming/Filename:
  #   Enabled: true
  # ```
  class Filename < Base
    properties do
      description "Enforces file names to be in underscored case"
    end

    MSG = "Filename should be underscore-cased: %s, not %s"

    private LOCATION = {1, 1}

    def test(source : Source)
      path = Path[source.path]
      name = path.basename

      return if (expected = name.underscore) == name

      issue_for LOCATION, MSG % {expected, name}
    end
  end
end
