module Ameba::Rule
  # A rule that disallows the use of `while true` instead of using the idiomatic `loop`
  #
  # For example, this is considered invalid:
  #
  # ```
  # while true
  #   do_something
  #   break if some_condition
  # end
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # loop do
  #   do_something
  #   break if some_condition
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # WhileTrue:
  #   Enabled: true
  # ```
  #
  struct WhileTrue < Base
    properties do
      description = "Disallows while statements with a true literal as condition"
    end

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::While)
      return unless node.cond.true_literal?
      source.error self, node.location, "While statement using true literal as condition"
    end
  end
end
