module Ameba::Rule
  # A rule that disallows tautological predicate names, meaning those that
  # start with the prefix `has_` or the prefix `is_`. Ignores if the alternative isn't valid Crystal code (e.g. `is_404?`).
  #
  # Favour these:
  #
  # ```
  # def valid?(x)
  # end
  #
  # def picture?(x)
  # end
  # ```
  #
  # Over these:
  #
  # ```
  # def is_valid?(x)
  # end
  #
  # def has_picture?(x)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # PredicateName:
  #   Enabled: true
  # ```
  #
  struct PredicateName < Base
    properties do
      description = "Disallows tautological predicate names"
    end

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Def)
      if node.name =~ /^(is|has)_(\w+)\?/
        alternative = $2
        return unless alternative =~ /^[a-z][a-zA-Z_0-9]*$/

        source.error self, node.location,
          "Favour method name '#{alternative}?' over '#{node.name}'"
      end
    end
  end
end
