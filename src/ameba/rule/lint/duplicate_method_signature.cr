module Ameba::Rule::Lint
  # Reports repeated class or module method signatures.
  #
  # Only methods of the same signature are considered duplicates,
  # regardless of their bodies, except for ones including `previous_def`.
  #
  # ```
  # class Foo
  #   def greet(name)
  #     puts "Hello #{name}!"
  #   end
  #
  #   def greet(name) # duplicated method signature
  #     puts "¡Hola! #{name}"
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DuplicateMethodSignature:
  #   Enabled: true
  # ```
  class DuplicateMethodSignature < Base
    properties do
      since_version "1.7.0"
      description "Reports repeated method signatures"
    end

    MSG = "Duplicate method signature detected"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef, scope : AST::Scope)
      found_defs = Set(String).new

      each_def_node(node) do |def_node|
        def_node_to_s = def_node.to_s

        next if def_node_to_s.matches?(/\Wprevious_def\W/)
        next if found_defs.add?(def_node_to_s.lines.first)

        issue_for def_node, MSG
      end
    end

    private def each_def_node(node, &)
      case body = node.body
      when Crystal::Def
        yield body
      when Crystal::VisibilityModifier
        yield body.exp
      when Crystal::Expressions
        body.expressions.each do |exp|
          case exp
          when Crystal::Def                then yield exp
          when Crystal::VisibilityModifier then yield exp.exp
          end
        end
      end
    end
  end
end
