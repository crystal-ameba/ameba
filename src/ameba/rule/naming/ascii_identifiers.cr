module Ameba::Rule::Naming
  # A rule that reports non-ascii characters in identifiers.
  #
  # Favour this:
  #
  # ```
  # class BigAwesomeWolf
  # end
  # ```
  #
  # Over this:
  #
  # ```
  # class BigAwesome🐺
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/AsciiIdentifiers:
  #   Enabled: true
  # ```
  class AsciiIdentifiers < Base
    include AST::Util

    properties do
      description "Disallows non-ascii characters in identifiers"
    end

    MSG = "Identifier contains non-ascii characters"

    def test(source, node : Crystal::Assign)
      if (target = node.target).is_a?(Crystal::Path)
        check_issue(source, target, target)
      end
    end

    def test(source, node : Crystal::MultiAssign)
      node.targets.each do |target|
        check_issue(source, target, target)
      end
    end

    def test(source, node : Crystal::Def)
      check_issue_with_location(source, node)

      node.args.each do |arg|
        check_issue_with_location(source, arg)
      end
    end

    def test(source, node : Crystal::ClassVar | Crystal::InstanceVar | Crystal::Var | Crystal::Alias)
      check_issue_with_location(source, node)
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef | Crystal::LibDef)
      check_issue(source, node.name, node.name)
    end

    private def check_issue_with_location(source, node)
      location = name_location(node)
      end_location = name_end_location(node)

      if location && end_location
        check_issue(source, location, end_location, node.name)
      else
        check_issue(source, node, node.name)
      end
    end

    private def check_issue(source, location, end_location, name)
      issue_for location, end_location, MSG unless name.to_s.ascii_only?
    end

    private def check_issue(source, node, name)
      issue_for node, MSG unless name.to_s.ascii_only?
    end
  end
end
