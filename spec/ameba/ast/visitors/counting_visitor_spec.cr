require "../../../spec_helper"

module Ameba::AST
  describe CountingVisitor do
    describe "#visit" do
      it "allow to visit ASTNode" do
        node = Crystal::Parser.new("").parse
        visitor = CountingVisitor.new node
        node.accept visitor
      end
    end

    describe "#count" do
      it "is 1 for an empty method" do
        node = Crystal::Parser.new("def hello; end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 1
      end

      it "is 1 if there is Macro::For" do
        code = <<-CRYSTAL
          def initialize
            {% for c in ALL_NODES %}
              true || false
            {% end %}
          end
          CRYSTAL
        node = Crystal::Parser.new(code).parse
        visitor = CountingVisitor.new node
        visitor.count.should eq 1
      end

      it "is 1 if there is Macro::If" do
        code = <<-CRYSTAL
          def initialize
            {% if foo.bar? %}
              true || false
            {% end %}
          end
          CRYSTAL
        node = Crystal::Parser.new(code).parse
        visitor = CountingVisitor.new node
        visitor.count.should eq 1
      end

      it "increases count for every exhaustive case" do
        code = <<-CRYSTAL
          def hello(a : Int32 | Int64 | Float32 | Float64)
            case a
            in Int32   then "int32"
            in Int64   then "int64"
            in Float32 then "float32"
            in Float64 then "float64"
            end
          end
          CRYSTAL
        node = Crystal::Parser.new(code).parse
        visitor = CountingVisitor.new node
        visitor.count.should eq 2
      end

      {% for pair in [
                       {code: "if true; end", description: "conditional"},
                       {code: "while true; end", description: "while loop"},
                       {code: "until 1 < 2; end", description: "until loop"},
                       {code: "begin; rescue; end", description: "rescue"},
                       {code: "true || false", description: "or"},
                       {code: "true && false", description: "and"},
                       {
                         code:        "a : String | Int32 = 1; case a when true; end",
                         description: "inexhaustive when",
                       },
                     ] %}
        it "increases count for every {{ pair[:description].id }}" do
          node = Crystal::Parser.new("def hello; {{ pair[:code].id }} end").parse
          visitor = CountingVisitor.new node

          visitor.count.should eq 2
        end
      {% end %}
    end
  end
end
