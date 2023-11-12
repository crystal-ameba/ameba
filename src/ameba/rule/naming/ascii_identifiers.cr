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
      check_issue(source, node, prefer_name_location: true)

      node.args.each do |arg|
        check_issue(source, arg, prefer_name_location: true)
      end
    end

    def test(source, node : Crystal::ClassVar | Crystal::InstanceVar | Crystal::Var | Crystal::Alias)
      check_issue(source, node, prefer_name_location: true)
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef | Crystal::LibDef)
      check_issue(source, node.name, node.name)
    end

    private def check_issue(source, location, end_location, name)
      issue_for location, end_location, MSG unless name.to_s.ascii_only?
    end

    private def check_issue(source, node, name = node.name, *, prefer_name_location = false)
      issue_for node, MSG, prefer_name_location: prefer_name_location unless name.to_s.ascii_only?
    end
  end
end
