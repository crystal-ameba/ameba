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
        Crystal::RegexLiteral.new(Crystal::NilLiteral.new),
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

    describe "#string_literal?" do
      it "returns true if node is a string literal" do
        subject.string_literal?(Crystal::StringLiteral.new "").should be_true
      end

      it "returns false if node is not a string literal" do
        subject.string_literal?(Crystal::Nop.new).should be_false
      end
    end
  end
end
