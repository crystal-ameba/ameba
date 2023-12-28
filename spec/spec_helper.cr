require "spec"
require "../src/ameba"
require "../src/ameba/spec/support"

module Ameba
  # Dummy Rule which does nothing.
  class DummyRule < Rule::Base
    properties do
      description "Dummy rule that does nothing."
      dummy true
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

  # Rule extended description
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

    def test(source, node : Crystal::VisibilityModifier, scope : AST::Scope)
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
    property? should_raise = false

    properties do
      description "Internal rule that always raises"
    end

    def test(source)
      should_raise? && raise "something went wrong"
    end
  end

  class PerfRule < Rule::Performance::Base
    properties do
      description "Sample performance rule"
    end

    def test(source)
      issue_for({1, 1}, "Poor performance")
    end
  end

  class AtoAA < Rule::Base
    include AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      return unless name = node_source(node.name, source.lines)
      return unless name.includes?("A")

      issue_for(node.name, message: "A to AA") do |corrector|
        corrector.replace(node.name, name.sub("A", "AA"))
      end
    end
  end

  class AtoB < Rule::Base
    include AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      return unless name = node_source(node.name, source.lines)
      return unless name.includes?("A")

      issue_for(node.name, message: "A to B") do |corrector|
        corrector.replace(node.name, name.tr("A", "B"))
      end
    end
  end

  class BtoA < Rule::Base
    include AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      return unless name = node_source(node.name, source.lines)
      return unless name.includes?("B")

      issue_for(node.name, message: "B to A") do |corrector|
        corrector.replace(node.name, name.tr("B", "A"))
      end
    end
  end

  class BtoC < Rule::Base
    include AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      return unless name = node_source(node.name, source.lines)
      return unless name.includes?("B")

      issue_for(node.name, message: "B to C") do |corrector|
        corrector.replace(node.name, name.tr("B", "C"))
      end
    end
  end

  class CtoA < Rule::Base
    include AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef | Crystal::ModuleDef)
      return unless name = node_source(node.name, source.lines)
      return unless name.includes?("C")

      issue_for(node.name, message: "C to A") do |corrector|
        corrector.replace(node.name, name.tr("C", "A"))
      end
    end
  end

  class ClassToModule < Ameba::Rule::Base
    include Ameba::AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ClassDef)
      return unless location = node.location

      end_location = location.adjust(column_number: {{ "class".size - 1 }})

      issue_for(location, end_location, message: "class to module") do |corrector|
        corrector.replace(location, end_location, "module")
      end
    end
  end

  class ModuleToClass < Ameba::Rule::Base
    include Ameba::AST::Util

    properties do
      description "This rule is only used to test infinite loop detection"
    end

    def test(source, node : Crystal::ModuleDef)
      return unless location = node.location

      end_location = location.adjust(column_number: {{ "module".size - 1 }})

      issue_for(location, end_location, message: "module to class") do |corrector|
        corrector.replace(location, end_location, "class")
      end
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
    NODES = {
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
    }

    def initialize(node)
      node.accept self
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    {% for node in NODES %}
      {{ getter_name = node.stringify.split("::").last.underscore + "_nodes" }}

      getter {{ getter_name.id }} = [] of {{ node }}

      def visit(node : {{ node }})
        {{ getter_name.id }} << node
        true
      end
    {% end %}
  end
end

def with_presenter(klass, &)
  io = IO::Memory.new
  presenter = klass.new(io)

  yield presenter, io
end

def as_node(source)
  Crystal::Parser.new(source).parse
end

def as_nodes(source)
  Ameba::TestNodeVisitor.new(as_node source)
end

def trailing_whitespace
  ' '
end
