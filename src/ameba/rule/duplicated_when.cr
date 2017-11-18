module Ameba::Rule
  # A rule that disallows duplicated when conditions in case.
  #
  # This is considered invalid:
  #
  # ```
  # case a
  # when "first"
  #   do_something
  # when "first"
  #   do_somehting_else
  # end
  # ```
  #
  # And it should be written as follows:
  #
  # ```
  # case a
  # when "first"
  #   do_something
  # when "second"
  #   do_somehting_else
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # DuplicatedWhen:
  #   Enabled: true
  # ```
  #
  struct DuplicatedWhen < Base
    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Case)
      return unless duplicated_whens?(node.whens)

      source.error self, node.location, "Duplicated when conditions in case."
    end

    private def duplicated_whens?(whens)
      whens.map(&.conds.map &.to_s)
           .flatten
           .group_by(&.itself)
           .any? { |_, v| v.size > 1 }
    end
  end
end
