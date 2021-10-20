require "spec"
require "../src/ameba"
require "../src/ameba/spec_support"

module Ameba
  # Dummy Rule which does nothing.
  class DummyRule < Rule::Base
    properties do
      description : String = "Dummy rule that does nothing."
    end

    def test(source)
    end
  end

  class NamedRule < Rule::Base
    properties do
      description "A rule with a custom name."
    end

    def self.name
      "BreakingRule"
    end
  end

  class ErrorRule < Rule::Base
    properties do
      description "Always adds an error at 1:1"
    end

    def test(source)
      issue_for({1, 1}, "This rule always adds an error")
    end
  end

  class ScopeRule < Rule::Base
    @[YAML::Field(ignore: true)]
    getter scopes = [] of AST::Scope

    properties do
      description "Internal rule to test scopes"
    end

    def test(source, node : Crystal::ASTNode, scope : AST::Scope)
      @scopes << scope
    end
  end

  class FlowExpressionRule < Rule::Base
    @[YAML::Field(ignore: true)]
    getter expressions = [] of AST::FlowExpression

    properties do
      description "Internal rule to test flow expressions"
    end

    def test(source, node, flow_expression : AST::FlowExpression)
      @expressions << flow_expression
    end
  end

  class RedundantControlExpressionRule < Rule::Base
    @[YAML::Field(ignore: true)]
    getter nodes = [] of Crystal::ASTNode

    properties do
      description "Internal rule to test redundant control expressions"
    end

    def test(source, node, visitor : AST::RedundantControlExpressionVisitor)
      nodes << node
    end
  end

  # A rule that always raises an error
  class RaiseRule < Rule::Base
    property should_raise = false

    properties do
      description "Internal rule that always raises"
    end

    def test(source)
      should_raise && raise "something went wrong"
    end
  end

  class PerfRule < Rule::Performance::Base
    properties do
      description : String = "Sample performance rule"
    end

    def test(source)
      issue_for({1, 1}, "Poor performance")
    end
  end

  class DummyFormatter < Formatter::BaseFormatter
    property started_sources : Array(Source)?
    property finished_sources : Array(Source)?
    property started_source : Source?
    property finished_source : Source?

    def started(sources)
      @started_sources = sources
    end

    def source_finished(source : Source)
      @started_source = source
    end

    def source_started(source : Source)
      @finished_source = source
    end

    def finished(sources)
      @finished_sources = sources
    end
  end

  class TestNodeVisitor < Crystal::Visitor
    NODES = [
      Crystal::NilLiteral,
      Crystal::Var,
      Crystal::Assign,
      Crystal::OpAssign,
      Crystal::MultiAssign,
      Crystal::Block,
      Crystal::Macro,
      Crystal::Def,
      Crystal::If,
      Crystal::While,
      Crystal::MacroLiteral,
      Crystal::Expressions,
      Crystal::ControlExpression,
    ]

    def initialize(node)
      node.accept self
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    {% for node in NODES %}
      {{getter_name = node.stringify.split("::").last.underscore + "_nodes"}}

      getter {{getter_name.id}} = [] of {{node}}

      def visit(node : {{node}})
        {{getter_name.id}} << node
        true
      end
    {% end %}
  end
end

def as_node(source)
  Crystal::Parser.new(source).parse
end

def as_nodes(source)
  Ameba::TestNodeVisitor.new(as_node source)
end
