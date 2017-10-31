module Ameba
  macro rule(name, &block)
    module Ameba::Rules
      struct {{name.id}} < Rule
        def test(source)
          {{block.body}}
        end
      end
    end
  end

  macro visitor(name, node, &block)
    module Ameba::Rules
      class {{name.id}}Visitor < Crystal::Visitor
        @rule : Rule
        @source : Source

        def initialize(@rule, @source)
          @source.ast.accept self
        end

        def visit(node : Crystal::ASTNode)
          true
        end

        def visit(node : {{node.id}})
          {{block.body}}
        end
      end
    end
  end
end
