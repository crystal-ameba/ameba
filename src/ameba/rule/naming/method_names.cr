module Ameba::Rule::Naming
  # A rule that enforces method names to be in underscored case.
  #
  # For example, these are considered valid:
  #
  # ```
  # class Person
  #   def first_name
  #   end
  #
  #   def date_of_birth
  #   end
  #
  #   def homepage_url
  #   end
  # end
  # ```
  #
  # And these are invalid method names:
  #
  # ```
  # class Person
  #   def firstName
  #   end
  #
  #   def date_of_Birth
  #   end
  #
  #   def homepageURL
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/MethodNames:
  #   Enabled: true
  # ```
  class MethodNames < Base
    properties do
      description "Enforces method names to be in underscored case"
    end

    MSG = "Method name should be underscore-cased: %s, not %s"

    def test(source, node : Crystal::Def)
      name = node.name.to_s

      return if (expected = name.underscore) == name

      issue_for node, MSG % {expected, name}, prefer_name_location: true
    end
  end
end
