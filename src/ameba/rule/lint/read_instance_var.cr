module Ameba::Rule::Lint
  # A rule that disallows reading instance variables externally from an object
  # via the `object.@ivar` syntax.
  #
  # This is only allowed when inside a method def in a class, and the object
  # is typed to be the same as the current class.
  #
  # For example, this is not allowed:
  #
  # ```
  # class Greeter
  #   def combine(other)
  #     @ivar <=> other.@ivar
  #   end
  #
  #   def split(other : Smiler)
  #     @ivar - other.@ivar
  #   end
  # end
  # ```
  #
  # And this is allowed:
  #
  # ```
  # class Greeter
  #   def combine(other : self)
  #     @ivar <=> other.@ivar
  #   end
  #
  #   def split(other : Greeter)
  #     @ivar - other.@ivar
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ReadInstanceVar:
  #   Enabled: false
  # ```
  class ReadInstanceVar < Base
    properties do
      description "Disallows external reading of instance vars"
    end

    MSG = "Reading instance variables externally is not allowed."

    def test(source)
      InstanceVarReadVisitor.new(self, source)
    end

    def test(
      source, node : Crystal::ReadInstanceVar,
      allowed_names : Array(String)
    ) : Nil
      case obj = node.obj
      when Crystal::Var
        unless obj.name.in?(allowed_names)
          issue_for node, MSG, prefer_name_location: true
        end
      else
        issue_for node, MSG, prefer_name_location: true
      end
    end

    private class InstanceVarReadVisitor < AST::NodeVisitor
      @class_name : String?
      @param_names : Array(String) = [] of String

      def visit(node : Crystal::ClassDef) : Nil
        prev_class = @class_name
        @class_name = node.name.names[-1]?

        node.body.accept(self)

        @class_name = prev_class
      end

      def visit(node : Crystal::Def)
        node.args.each do |arg|
          case restriction = arg.restriction
          when Crystal::Path
            if restriction.names[-1]? == @class_name
              @param_names << arg.name
            end
          when Crystal::Self
            @param_names << arg.name
          end
        end

        super
      end

      def end_visit(node : Crystal::Def)
        @param_names.clear
        super
      end

      def visit(node : Crystal::ReadInstanceVar)
        @rule.test(@source, node, @param_names)
        super
      end
    end
  end
end
