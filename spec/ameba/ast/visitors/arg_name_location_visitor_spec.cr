require "../../../spec_helper"

module Ameba::AST
  describe ArgNameLocationVisitor do
    {
      "def foo(bar baz); end"         => 13,
      "def foo(bar    baz); end"      => 16,
      %(def foo("bar" baz); end)      => 15,
      %(def foo("b\\" r" baz); end)   => 17,
      "def foo(bar baz : Int32); end" => 13,
      "def foo(@baz); end"            => 10,
      "def foo(@@baz); end"           => 11,
      "def foo(bar @baz); end"        => 14,
      "macro foo(bar baz); end"       => 15,
    }.each do |code, column|
      it "sets the argument name location in `#{code}`" do
        args =
          case node = Source.new(code).ast
          when Crystal::Def, Crystal::Macro then node.args
          else                                   fail "Unexpected node: #{node}"
          end

        location = args.first.name_location.should_not be_nil
        location.line_number.should eq 1
        location.column_number.should eq column
      end
    end

    {
      "def foo(baz); end",
      "def foo(baz : Int32); end",
      "def foo(*baz); end",
      "def foo(@select); end",
    }.each do |code|
      it "doesn't set the argument name location in `#{code}`" do
        node = Source.new(code).ast.should be_a(Crystal::Def)
        node.args.first.name_location.should be_nil
      end
    end
  end
end
