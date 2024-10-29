module Ameba::Rule::Naming
  # A rule that makes sure that accessor methods are named properly.
  #
  # Favour this:
  #
  # ```
  # class Foo
  #   def user
  #     @user
  #   end
  #
  #   def user=(value)
  #     @user = value
  #   end
  # end
  # ```
  #
  # Over this:
  #
  # ```
  # class Foo
  #   def get_user
  #     @user
  #   end
  #
  #   def set_user(value)
  #     @user = value
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/AccessorMethodName:
  #   Enabled: true
  # ```
  class AccessorMethodName < Base
    properties do
      description "Makes sure that accessor methods are named properly"
    end

    MSG = "Favour method name '%s' over '%s'"

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      each_def_node(node) do |def_node|
        # skip defs with explicit receiver, as they'll be handled
        # by the `test(source, node : Crystal::Def)` overload
        check_issue(source, def_node) unless def_node.receiver
      end
    end

    def test(source, node : Crystal::Def)
      # check only defs with explicit receiver (`def self.foo`)
      check_issue(source, node) if node.receiver
    end

    private def each_def_node(node, &)
      case body = node.body
      when Crystal::Def
        yield body
      when Crystal::Expressions
        body.expressions.each do |exp|
          yield exp if exp.is_a?(Crystal::Def)
        end
      end
    end

    private def check_issue(source, node : Crystal::Def)
      case node.name
      when /^get_([a-z]\w*)$/
        return unless node.args.empty?
        issue_for node, MSG % {$1, node.name}, prefer_name_location: true
      when /^set_([a-z]\w*)$/
        return unless node.args.size == 1
        issue_for node, MSG % {"#{$1}=", node.name}, prefer_name_location: true
      end
    end
  end
end
