require "../../spec_helper"

module Ameba::AST
  describe Scope do
    describe "#initialize" do
      source = "a = 2"

      it "assigns outer scope" do
        root = Scope.new(as_node(source))
        child = Scope.new(as_node(source), root)
        child.outer_scope.should_not be_nil
      end

      it "assigns node" do
        scope = Scope.new(as_node(source))
        scope.node.should_not be_nil
      end

      it "registers regular and unpacked block arguments" do
        node = as_node("foo { |a, (b, *c)| }").as(Crystal::Call)
        block = node.block.should be_a(Crystal::Block)

        scope = Scope.new(block)
        scope.arguments.map(&.name).should eq %w[a b c]
      end

      it "registers def arguments" do
        scope = Scope.new(as_node("def foo(a, *b, c = 1, **d, &e); end"))
        scope.arguments.map(&.name).should eq %w[a b c d e]
      end

      it "registers macro arguments" do
        scope = Scope.new(as_node("macro foo(a, *b, **c, &d); end"))
        scope.arguments.map(&.name).should eq %w[a b c d]
      end

      it "registers proc arguments" do
        scope = Scope.new(as_node("->(a : Int32, b : String) { }"))
        scope.arguments.map(&.name).should eq %w[a b]
      end

      it "registers fun arguments" do
        scope = Scope.new(as_node("fun foo(a : Int32, b : Int32) : Int32; end"))
        scope.arguments.map(&.name).should eq %w[a b]
      end

      it "does not register arguments for other nodes" do
        scope = Scope.new(as_node("enum Foo; A; B; end"))
        scope.arguments.should be_empty
      end
    end

    describe "#arg?" do
      it "returns true for regular and unpacked block arguments" do
        node = as_node("foo { |a, (b, *c)| }").as(Crystal::Call)
        block = node.block.should be_a(Crystal::Block)
        scope = Scope.new(block)

        AST::Util.all_block_args(block).each do |arg|
          scope.arg?(arg).should be_true
        end
        scope.arg?(Crystal::Var.new("b")).should be_false
      end
    end
  end

  describe "delegation" do
    it "delegates to_s to node" do
      node = as_node("def foo; end")
      scope = Scope.new(node)
      scope.to_s.should eq node.to_s
    end

    it "delegates locations to node" do
      node = as_node("def foo; end")
      scope = Scope.new(node)
      scope.location.should eq node.location
      scope.end_location.should eq node.end_location
    end
  end

  describe "#references" do
    it "can return an empty list of references" do
      scope = Scope.new(as_node(""))
      scope.references.should be_empty
    end

    it "allows to add variable references" do
      scope = Scope.new(as_node(""))
      nodes = as_nodes("a = 2")
      scope.references << Reference.new(nodes.var_nodes.first, scope)
      scope.references.size.should eq 1
    end
  end

  describe "#references?" do
    it "returns true if current scope references variable" do
      nodes = as_nodes <<-CRYSTAL
        def method
          a = 2
          block do
            3.times { |i| a = a + i }
          end
        end
        CRYSTAL

      var_node = nodes.var_nodes.first

      scope = Scope.new(nodes.def_nodes.first)
      scope.add_variable(var_node)
      scope.inner_scopes << Scope.new(nodes.block_nodes.first, scope)

      variable = Variable.new(var_node, scope)
      variable.reference(nodes.var_nodes.first, scope.inner_scopes.first)

      scope.references?(variable).should be_true
    end

    it "returns false if inner scopes are not checked" do
      nodes = as_nodes <<-CRYSTAL
        def method
          a = 2
          block do
            3.times { |i| a = a + i }
          end
        end
        CRYSTAL

      var_node = nodes.var_nodes.first

      scope = Scope.new(nodes.def_nodes.first)
      scope.add_variable(var_node)
      scope.inner_scopes << Scope.new(nodes.block_nodes.first, scope)

      variable = Variable.new(var_node, scope)
      variable.reference(nodes.var_nodes.first, scope.inner_scopes.first)

      scope.references?(variable, check_inner_scopes: false).should be_false
    end

    it "returns true if a deeply nested inner scope references variable" do
      nodes = as_nodes <<-CRYSTAL
        def method
          a = 2
          1.times { 2.times { 3.times { a } } }
        end
        CRYSTAL

      scope = Scope.new(nodes.def_nodes.first)
      inner_scope = nodes.block_nodes.reduce(scope) do |outer_scope, block_node|
        Scope.new(block_node, outer_scope)
      end

      variable = Variable.new(nodes.var_nodes.first, scope)
      variable.reference(nodes.var_nodes.last, inner_scope)

      scope.references?(variable).should be_true
      scope.inner_scopes.first.references?(variable).should be_true
      scope.references?(variable, check_inner_scopes: false).should be_false
    end

    it "returns false if current scope does not reference variable" do
      nodes = as_nodes <<-CRYSTAL
        def method
          a = 2
          block do
            b = 3
            3.times { |i| b = b + i }
          end
        end
        CRYSTAL

      var_node = nodes.var_nodes.first

      scope = Scope.new(nodes.def_nodes.first)
      scope.add_variable(var_node)
      scope.inner_scopes << Scope.new(nodes.block_nodes.first, scope)

      variable = Variable.new(var_node, scope)

      scope.inner_scopes.first.references?(variable).should be_false
    end
  end

  describe "#nested_in?" do
    it "returns true if the scope is nested within the given scope" do
      nodes = as_nodes <<-CRYSTAL
        def method
          1.times { 2.times { } }
        end
        CRYSTAL

      scope = Scope.new(nodes.def_nodes.first)
      inner_scope = Scope.new(nodes.block_nodes.first, scope)
      inner_inner_scope = Scope.new(nodes.block_nodes.last, inner_scope)

      inner_scope.nested_in?(scope).should be_true
      inner_inner_scope.nested_in?(scope).should be_true
      inner_inner_scope.nested_in?(inner_scope).should be_true
    end

    it "returns false if the scope is not nested within the given scope" do
      nodes = as_nodes <<-CRYSTAL
        def method
          1.times { }
          2.times { }
        end
        CRYSTAL

      scope = Scope.new(nodes.def_nodes.first)
      inner_scope = Scope.new(nodes.block_nodes.first, scope)
      sibling_scope = Scope.new(nodes.block_nodes.last, scope)

      scope.nested_in?(scope).should be_false
      scope.nested_in?(inner_scope).should be_false
      inner_scope.nested_in?(sibling_scope).should be_false
    end
  end

  describe "#add_variable" do
    it "adds a new variable to the scope" do
      scope = Scope.new(as_node(""))
      scope.add_variable(Crystal::Var.new("foo"))
      scope.variables.empty?.should be_false
    end
  end

  describe "#add_out_variable" do
    it "declares and assigns the out variable" do
      node = as_node("foo(out x)").as(Crystal::Call)
      out_node = node.args.first.as(Crystal::Out)
      scope = Scope.new(node)

      variable = scope.add_out_variable(out_node).should_not be_nil
      variable.name.should eq "x"
      variable.node.should be(out_node.exp)
      variable.assignments.map(&.node).should eq [out_node]
    end

    it "does nothing if the out argument is not a local variable" do
      node = as_node("foo(out @x)").as(Crystal::Call)
      scope = Scope.new(node)

      scope.add_out_variable(node.args.first.as(Crystal::Out)).should be_nil
      scope.variables.should be_empty
    end
  end

  describe "#add_rescue_variable" do
    it "declares and assigns the rescue variable" do
      node = as_node("begin; rescue ex; end").as(Crystal::ExceptionHandler)
      rescues = node.rescues.should_not be_nil
      rescue_node = rescues.first
      scope = Scope.new(node)

      variable = scope.add_rescue_variable(rescue_node).should_not be_nil
      variable.name.should eq "ex"
      variable.assignments.map(&.node).should eq [rescue_node]

      location = variable.location.should_not be_nil
      location.column_number.should eq 15
    end

    it "does nothing if the rescue has no variable" do
      node = as_node("begin; rescue; end").as(Crystal::ExceptionHandler)
      scope = Scope.new(node)

      rescues = node.rescues.should_not be_nil
      scope.add_rescue_variable(rescues.first).should be_nil
      scope.variables.should be_empty
    end
  end

  describe "#find_variable" do
    it "returns the variable in the scope by name" do
      scope = Scope.new(as_node("foo = 1"))
      scope.add_variable(Crystal::Var.new("foo"))
      scope.find_variable("foo").should_not be_nil
    end

    it "returns nil if variable not exist in this scope" do
      scope = Scope.new(as_node("foo = 1"))
      scope.find_variable("bar").should be_nil
    end
  end

  describe "#assign_variable" do
    it "creates a new assignment" do
      scope = Scope.new(as_node("foo = 1"))
      scope.add_variable(Crystal::Var.new("foo"))
      scope.assign_variable("foo", Crystal::Var.new("foo"))
      var = scope.find_variable("foo").should_not be_nil
      var.assignments.size.should eq 1
    end

    it "does not create the assignment if variable is wrong" do
      scope = Scope.new(as_node("foo = 1"))
      scope.add_variable(Crystal::Var.new("foo"))
      scope.assign_variable("bar", Crystal::Var.new("bar"))
      var = scope.find_variable("foo").should_not be_nil
      var.assignments.size.should eq 0
    end
  end

  describe "#inherits_variables?" do
    it "returns true for a block" do
      nodes = as_nodes("3.times {}")
      scope = Scope.new(nodes.block_nodes.first)
      scope.inherits_variables?.should be_true
    end

    it "returns false for a method" do
      nodes = as_nodes("def foo; end")
      scope = Scope.new(nodes.def_nodes.first)
      scope.inherits_variables?.should be_false
    end

    it "returns false for a type definition" do
      scope = Scope.new(as_node("class Foo; end"))
      scope.inherits_variables?.should be_false
    end
  end

  describe "#block?" do
    it "returns true if Crystal::Block" do
      nodes = as_nodes("3.times {}")
      scope = Scope.new(nodes.block_nodes.first)
      scope.block?.should be_true
    end

    it "returns false otherwise" do
      scope = Scope.new(as_node("a = 1"))
      scope.block?.should be_false
    end
  end

  describe "#spawn_block?" do
    it "returns true if a node is a spawn block" do
      nodes = as_nodes("spawn {}")
      scope = Scope.new(nodes.block_nodes.first)
      scope.spawn_block?.should be_true
    end

    it "returns false otherwise" do
      scope = Scope.new(as_node("a = 1"))
      scope.spawn_block?.should be_false
    end
  end

  describe "#def?" do
    context "when check_outer_scopes: true" do
      it "returns true if outer scope is Crystal::Def" do
        nodes = as_nodes("def foo; 3.times {}; end")
        outer_scope = Scope.new(nodes.def_nodes.first)
        scope = Scope.new(nodes.block_nodes.first, outer_scope)
        scope.def?(check_outer_scopes: true).should be_true
        scope.def?.should be_false
      end
    end

    it "returns true if Crystal::Def" do
      nodes = as_nodes("def foo; end")
      scope = Scope.new(nodes.def_nodes.first)
      scope.def?.should be_true
    end

    it "returns false otherwise" do
      scope = Scope.new(as_node("a = 1"))
      scope.def?.should be_false
    end
  end

  describe "#in_macro?" do
    it "returns true if Crystal::Macro" do
      nodes = as_nodes <<-CRYSTAL
        macro included
        end
        CRYSTAL
      scope = Scope.new(nodes.macro_nodes.first)
      scope.in_macro?.should be_true
    end

    it "returns true if node is nested to Crystal::Macro" do
      nodes = as_nodes <<-CRYSTAL
        macro included
          {{ @type.each do |type| a = type end }}
        end
        CRYSTAL
      outer_scope = Scope.new(nodes.macro_nodes.first)
      scope = Scope.new(nodes.block_nodes.first, outer_scope)
      scope.in_macro?.should be_true
    end

    it "returns false otherwise" do
      scope = Scope.new(as_node("a = 1"))
      scope.in_macro?.should be_false
    end
  end
end
