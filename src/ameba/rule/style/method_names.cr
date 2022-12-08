module Ameba::Rule::Style
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
  # Style/MethodNames:
  #   Enabled: true
  # ```
  class MethodNames < Base
    include AST::Util

    properties do
      description "Enforces method names to be in underscored case"
    end

    MSG = "Method name should be underscore-cased: %s, not %s"

    def test(source, node : Crystal::Def)
      return if (expected = node.name.underscore) == node.name

      return unless location = name_location(node)
      return unless end_location = name_end_location(node)

      issue_for location, end_location, MSG % {expected, node.name}
    end
  end
end
