require "../../../spec_helper"

module Ameba::AST
  describe Assignment do
    node = Crystal::NilLiteral.new
    scope = Scope.new as_node "foo = 1"
    variable = Variable.new(Crystal::Var.new("foo"), scope)

    describe "#initialize" do
      it "creates a new assignment with node and var" do
        assignment = Assignment.new(node, variable, scope)
        assignment.node.should_not be_nil
      end
    end

    describe "#reference=" do
      it "creates a new reference" do
        assignment = Assignment.new(node, variable, scope)
        assignment.referenced = true
        assignment.referenced?.should be_true
      end
    end

    describe "delegation" do
      it "delegates locations" do
        assignment = Assignment.new(node, variable, scope)
        assignment.location.should eq node.location
        assignment.end_location.should eq node.end_location
      end

      it "delegates to_s" do
        assignment = Assignment.new(node, variable, scope)
        assignment.to_s.should eq node.to_s
      end

      it "delegates scope" do
        assignment = Assignment.new(node, variable, scope)
        assignment.scope.should eq variable.scope
      end
    end

    describe "#branch" do
      it "returns the branch of the assignment" do
        nodes = as_nodes <<-CRYSTAL
          def method(a)
            if a
              a = 3  # --> Crystal::Expressions
              puts a
            end
          end
          CRYSTAL
        scope = Scope.new nodes.def_nodes.first
        variable = Variable.new(nodes.var_nodes.first, scope)
        assignment = Assignment.new(nodes.assign_nodes.first, variable, scope)
        branch = assignment.branch.should_not be_nil
        branch.node.class.should eq Crystal::Expressions
      end

      it "returns inner branch" do
        nodes = as_nodes <<-CRYSTAL
          def method(a, b)
            if a
              if b
                a = 3 # --> Crystal::Assign
              end
            end
          end
          CRYSTAL
        scope = Scope.new nodes.def_nodes.first
        variable = Variable.new(nodes.var_nodes.first, scope)
        assignment = Assignment.new(nodes.assign_nodes.first, variable, scope)
        branch = assignment.branch.should_not be_nil
        branch.node.class.should eq Crystal::Assign
      end

      it "returns nil if assignment does not have a branch" do
        nodes = as_nodes <<-CRYSTAL
          def method(a)
            a = 2
          end
          CRYSTAL
        scope = Scope.new nodes.def_nodes.first
        variable = Variable.new(nodes.var_nodes.first, scope)
        assignment = Assignment.new(nodes.assign_nodes.first, variable, scope)
        assignment.branch.should be_nil
      end
    end
  end
end
