require "../../../spec_helper"

module Ameba::AST
  describe TypeDecVariable do
    var = Crystal::Var.new("foo")
    declared_type = Crystal::Path.new("String")
    type_dec = Crystal::TypeDeclaration.new(var, declared_type)

    describe "#initialize" do
      it "creates a new type dec variable" do
        variable = TypeDecVariable.new(type_dec)
        variable.node.should_not be_nil
      end
    end

    describe "#name" do
      it "returns var name" do
        variable = TypeDecVariable.new(type_dec)
        variable.name.should eq var.name
      end

      it "raises if type declaration is incorrect" do
        type_dec = Crystal::TypeDeclaration.new(declared_type, declared_type)

        expect_raises(Exception, "Unsupported var node type: Crystal::Path") do
          TypeDecVariable.new(type_dec).name
        end
      end
    end
  end
end
