require "../../spec_helper"

module Ameba::AST
  struct Test
    include Util
  end

  subject = Test.new

  describe Util do
    describe "#literal?" do
      [
        Crystal::ArrayLiteral.new,
        Crystal::BoolLiteral.new(false),
        Crystal::CharLiteral.new('a'),
        Crystal::HashLiteral.new,
        Crystal::NamedTupleLiteral.new,
        Crystal::NilLiteral.new,
        Crystal::NumberLiteral.new(42),
        Crystal::RegexLiteral.new(Crystal::StringLiteral.new("")),
        Crystal::StringLiteral.new(""),
        Crystal::SymbolLiteral.new(""),
        Crystal::TupleLiteral.new([] of Crystal::ASTNode),
        Crystal::RangeLiteral.new(
          Crystal::NilLiteral.new,
          Crystal::NilLiteral.new,
          true),
      ].each do |literal|
        it "returns true if node is #{literal}" do
          subject.literal?(literal).should be_true
        end
      end

      it "returns false if node is not a literal" do
        subject.literal?(Crystal::Nop).should be_false
      end
    end

    describe "#static/dynamic_literal?" do
      [
        Crystal::ArrayLiteral.new,
        Crystal::ArrayLiteral.new([Crystal::StringLiteral.new("foo")] of Crystal::ASTNode),
        Crystal::BoolLiteral.new(false),
        Crystal::CharLiteral.new('a'),
        Crystal::HashLiteral.new,
        Crystal::NamedTupleLiteral.new,
        Crystal::NilLiteral.new,
        Crystal::NumberLiteral.new(42),
        Crystal::RegexLiteral.new(Crystal::StringLiteral.new("")),
        Crystal::StringLiteral.new("foo"),
        Crystal::SymbolLiteral.new("foo"),
        Crystal::TupleLiteral.new([] of Crystal::ASTNode),
        Crystal::TupleLiteral.new([Crystal::StringLiteral.new("foo")] of Crystal::ASTNode),
        Crystal::RangeLiteral.new(
          Crystal::NumberLiteral.new(0),
          Crystal::NumberLiteral.new(10),
          true),
      ].each do |literal|
        it "properly identifies static node #{literal}" do
          subject.static_literal?(literal).should be_true
          subject.dynamic_literal?(literal).should be_false
        end
      end

      [
        Crystal::ArrayLiteral.new([Crystal::Path.new(%w[IO])] of Crystal::ASTNode),
        Crystal::TupleLiteral.new([Crystal::Path.new(%w[IO])] of Crystal::ASTNode),
      ].each do |literal|
        it "properly identifies dynamic node #{literal}" do
          subject.dynamic_literal?(literal).should be_true
          subject.static_literal?(literal).should be_false
        end
      end
    end

    describe "#node_source" do
      it "returns original source of the node" do
        s = <<-CRYSTAL
          a = 1
          CRYSTAL
        node = Crystal::Parser.new(s).parse
        source = subject.node_source node, s.split("\n")
        source.should eq "a = 1"
      end

      it "returns original source of multiline node" do
        s = <<-CRYSTAL
          if ()
            :ok
          end
          CRYSTAL
        node = Crystal::Parser.new(s).parse
        source = subject.node_source node, s.split("\n")
        source.should eq <<-CRYSTAL
          if ()
            :ok
          end
          CRYSTAL
      end

      it "does not report source of node which has incorrect location" do
        s = <<-'CRYSTAL'
          module MyModule
            macro conditional_error_for_inline_callbacks
              \{%
                raise ""
              %}
            end

            macro before_save(x = nil)
            end
          end
          CRYSTAL
        node = as_nodes(s).nil_literal_nodes.first
        source = subject.node_source node, s.split("\n")
        source.should eq "nil"
      end
    end

    describe "#flow_command?" do
      it "returns true if this is return" do
        node = as_node("return 22")
        subject.flow_command?(node, false).should eq true
      end

      it "returns true if this is a break in a loop" do
        node = as_node("break")
        subject.flow_command?(node, true).should eq true
      end

      it "returns false if this is a break out of loop" do
        node = as_node("break")
        subject.flow_command?(node, false).should be_false
      end

      it "returns true if this is a next in a loop" do
        node = as_node("next")
        subject.flow_command?(node, true).should eq true
      end

      it "returns false if this is a next out of loop" do
        node = as_node("next")
        subject.flow_command?(node, false).should be_false
      end

      it "returns true if this is raise" do
        node = as_node("raise e")
        subject.flow_command?(node, false).should eq true
      end

      it "returns true if this is exit" do
        node = as_node("exit")
        subject.flow_command?(node, false).should eq true
      end

      it "returns true if this is abort" do
        node = as_node("abort")
        subject.flow_command?(node, false).should eq true
      end

      it "returns false otherwise" do
        node = as_node("foobar")
        subject.flow_command?(node, false).should be_false
      end
    end

    describe "#flow_expression?" do
      it "returns true if this is a flow command" do
        node = as_node("return")
        subject.flow_expression?(node, true).should eq true
      end

      it "returns true if this is if-else consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          if foo
            return :foo
          else
            return :bar
          end
          CRYSTAL
        subject.flow_expression?(node, false).should eq true
      end

      it "returns true if this is unless-else consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          unless foo
            return :foo
          else
            return :bar
          end
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns true if this is case consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          case
          when 1
            return 1
          when 2
            return 2
          else
            return 3
          end
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns true if this is exception handler consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          begin
            raise "exp"
          rescue e
            return e
          end
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns true if this while consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          while true
            return
          end
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns false if this while with break" do
        node = as_node <<-CRYSTAL
          while true
            break
          end
          CRYSTAL
        subject.flow_expression?(node).should be_false
      end

      it "returns true if this until consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          until false
            return
          end
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns false if this until with break" do
        node = as_node <<-CRYSTAL
          until false
            break
          end
          CRYSTAL
        subject.flow_expression?(node).should be_false
      end

      it "returns true if this expressions consumed by flow expressions" do
        node = as_node <<-CRYSTAL
          exp1
          exp2
          return
          CRYSTAL
        subject.flow_expression?(node).should eq true
      end

      it "returns false otherwise" do
        node = as_node <<-CRYSTAL
          exp1
          exp2
          CRYSTAL
        subject.flow_expression?(node).should be_false
      end
    end

    describe "#raise?" do
      it "returns true if this is a raise method call" do
        node = as_node "raise e"
        subject.raise?(node).should eq true
      end

      it "returns false if it has a receiver" do
        node = as_node "obj.raise e"
        subject.raise?(node).should be_false
      end

      it "returns false if size of the arguments doesn't match" do
        node = as_node "raise"
        subject.raise?(node).should be_false
      end
    end

    describe "#exit?" do
      it "returns true if this is a exit method call" do
        node = as_node "exit"
        subject.exit?(node).should eq true
      end

      it "returns true if this is a exit method call with one argument" do
        node = as_node "exit 1"
        subject.exit?(node).should eq true
      end

      it "returns false if it has a receiver" do
        node = as_node "obj.exit"
        subject.exit?(node).should be_false
      end

      it "returns false if size of the arguments doesn't match" do
        node = as_node "exit 1, 1"
        subject.exit?(node).should be_false
      end
    end

    describe "#abort?" do
      it "returns true if this is an abort method call" do
        node = as_node "abort"
        subject.abort?(node).should eq true
      end

      it "returns true if this is an abort method call with one argument" do
        node = as_node "abort \"message\""
        subject.abort?(node).should eq true
      end

      it "returns true if this is an abort method call with two arguments" do
        node = as_node "abort \"message\", 1"
        subject.abort?(node).should eq true
      end

      it "returns false if it has a receiver" do
        node = as_node "obj.abort"
        subject.abort?(node).should be_false
      end

      it "returns false if size of the arguments doesn't match" do
        node = as_node "abort 1, 1, 1"
        subject.abort?(node).should be_false
      end
    end

    describe "#loop?" do
      it "returns true if this is a loop method call" do
        node = as_node "loop"
        subject.loop?(node).should eq true
      end

      it "returns false if it has a receiver" do
        node = as_node "obj.loop"
        subject.loop?(node).should be_false
      end

      it "returns false if size of the arguments doesn't match" do
        node = as_node "loop 1"
        subject.loop?(node).should be_false
      end
    end

    describe "#control_exp_code" do
      it "returns the exp code of a control expression" do
        s = "return 1"
        node = as_node(s).as Crystal::ControlExpression
        exp_code = subject.control_exp_code node, [s]
        exp_code.should eq "1"
      end

      it "wraps implicit tuple literal with curly brackets" do
        s = "return 1, 2"
        node = as_node(s).as Crystal::ControlExpression
        exp_code = subject.control_exp_code node, [s]
        exp_code.should eq "{1, 2}"
      end

      it "accepts explicit tuple literal" do
        s = "return {1, 2}"
        node = as_node(s).as Crystal::ControlExpression
        exp_code = subject.control_exp_code node, [s]
        exp_code.should eq "{1, 2}"
      end
    end

    describe "#name_end_location" do
      it "works on method call" do
        node = as_node("name(foo)").as Crystal::Call
        subject.name_end_location(node).to_s.should eq ":1:4"
      end

      it "works on method definition" do
        node = as_node("def name; end").as Crystal::Def
        subject.name_end_location(node).to_s.should eq ":1:8"
      end

      it "works on macro definition" do
        node = as_node("macro name; end").as Crystal::Macro
        subject.name_end_location(node).to_s.should eq ":1:10"
      end

      it "works on class definition" do
        node = as_node("class Name; end").as Crystal::ClassDef
        subject.name_end_location(node).to_s.should eq ":1:10"
      end

      it "works on module definition" do
        node = as_node("module Name; end").as Crystal::ModuleDef
        subject.name_end_location(node).to_s.should eq ":1:11"
      end

      it "works on annotation definition" do
        node = as_node("annotation Name; end").as Crystal::AnnotationDef
        subject.name_end_location(node).to_s.should eq ":1:15"
      end

      it "works on enum definition" do
        node = as_node("enum Name; end").as Crystal::EnumDef
        subject.name_end_location(node).to_s.should eq ":1:9"
      end

      it "works on alias definition" do
        node = as_node("alias Name = Foo").as Crystal::Alias
        subject.name_end_location(node).to_s.should eq ":1:10"
      end

      it "works on generic" do
        node = as_node("Name(Foo)").as Crystal::Generic
        subject.name_end_location(node).to_s.should eq ":1:4"
      end

      it "works on include" do
        node = as_node("include Name").as Crystal::Include
        subject.name_end_location(node).to_s.should eq ":1:12"
      end

      it "works on extend" do
        node = as_node("extend Name").as Crystal::Extend
        subject.name_end_location(node).to_s.should eq ":1:11"
      end

      it "works on variable type declaration" do
        node = as_node("name : Foo").as Crystal::TypeDeclaration
        subject.name_end_location(node).to_s.should eq ":1:4"
      end

      it "works on uninitialized variable" do
        node = as_node("name = uninitialized Foo").as Crystal::UninitializedVar
        subject.name_end_location(node).to_s.should eq ":1:4"
      end

      it "works on lib definition" do
        node = as_node("lib Name; end").as Crystal::LibDef
        subject.name_end_location(node).to_s.should eq ":1:8"
      end

      it "works on lib type definition" do
        node = as_node("lib Foo; type Name = Bar; end").as(Crystal::LibDef).body
        node.class.should eq Crystal::TypeDef
        subject.name_end_location(node).to_s.should eq ":1:18"
      end

      it "works on metaclass" do
        node = as_node("foo : Name.class").as(Crystal::TypeDeclaration).declared_type
        node.class.should eq Crystal::Metaclass
        subject.name_end_location(node).to_s.should eq ":1:10"
      end
    end
  end
end
