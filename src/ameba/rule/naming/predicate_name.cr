module Ameba::Rule::Naming
  # A rule that disallows tautological predicate names -
  # meaning those that start with the prefix `is_`, except for
  # the ones that are not valid Crystal code (e.g. `is_404?`).
  #
  # Favour this:
  #
  # ```
  # def valid?(x)
  # end
  # ```
  #
  # Over this:
  #
  # ```
  # def is_valid?(x)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/PredicateName:
  #   Enabled: true
  # ```
  class PredicateName < Base
    properties do
      description "Disallows tautological predicate names"
    end

    MSG = "Favour method name '%s?' over '%s'"

    def test(source, node : Crystal::Def)
      return unless node.name =~ /^is_([a-z]\w*)\??$/
      alternative = $1

      issue_for node, MSG % {alternative, node.name}, prefer_name_location: true
    end
  end
end
