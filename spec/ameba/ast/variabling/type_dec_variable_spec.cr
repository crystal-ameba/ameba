require "../../../spec_helper"

module Ameba::AST
  describe TypeDecVariable do
    var = Crystal::Var.new("foo")
    declared_type = Crystal::Path.new("String")

    describe "#initialize" do
      it "creates a new type dec variable" do
        type_dec = Crystal::TypeDeclaration.new(var, declared_type)

        variable = TypeDecVariable.new(type_dec)
        variable.node.should_not be_nil
      end
    end

    describe "#name" do
      it "returns var name" do
        type_dec = Crystal::TypeDeclaration.new(var, declared_type)

        variable = TypeDecVariable.new(type_dec)
        variable.name.should eq var.name
      end

      it "returns const name" do
        const = Crystal::Path.new(%w[Foo Bar])
        type_dec = Crystal::TypeDeclaration.new(const, declared_type)

        variable = TypeDecVariable.new(type_dec)
        variable.name.should eq const.names.join("::")
      end

      it "raises if type declaration is incorrect" do
        union = Crystal::Union.new([declared_type, declared_type] of Crystal::ASTNode)
        type_dec = Crystal::TypeDeclaration.new(union, declared_type)

        expect_raises(Exception, "Unsupported var node type: Crystal::Union") do
          TypeDecVariable.new(type_dec).name
        end
      end
    end
  end
end
