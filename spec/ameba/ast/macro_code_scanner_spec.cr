require "../../spec_helper"

private def scan(*literals : String) : Array(String)
  scanner = Ameba::AST::MacroCodeScanner.new
  literals.to_a { |literal| scanner.scan(literal) }
end

module Ameba::AST
  describe MacroCodeScanner do
    describe "#scan" do
      it "keeps the code" do
        scan("foo.bar(1, baz)\n").should eq ["foo.bar(1, baz)\n"]
      end

      it "keeps the number of characters" do
        literal = %(a = :ä + "ö" + 'ü' # ß\n)
        scan(literal).first.size.should eq literal.size
      end

      it "blanks out comments" do
        scan("foo # bar\nbaz\n").should eq ["foo      \nbaz\n"]
      end

      it "blanks out string literals" do
        scan(%(foo "bar" baz)).should eq ["foo       baz"]
        scan(%(foo "b\\"r" baz)).should eq ["foo        baz"]
      end

      it "keeps the code within interpolations" do
        scan(%("a\#{foo}b" + "\#{"c"}")).should eq [%(    foo    +         )]
        scan(%("\#{ {a: 1}[:a] }")).should eq [%(    {a: 1}[  ]   )]
      end

      it "blanks out char literals" do
        scan(%('a' + '"' + foo)).should eq ["    +     + foo"]
      end

      it "blanks out command literals" do
        scan("`foo \#{bar}` + baz").should eq ["       bar   + baz"]
      end

      it "blanks out symbol literals" do
        scan(%(:foo + :"bar" + baz)).should eq ["     +        + baz"]
      end

      it "keeps paths, named arguments and ternaries" do
        scan("Foo::Bar").should eq ["Foo::Bar"]
        scan("foo(bar: 1)").should eq ["foo(bar: 1)"]
        scan("a ? b : c").should eq ["a ? b : c"]
      end

      it "blanks out percent literals" do
        scan("%(a(b)c) + %w[d e] + %q{f} + %r<g>i + foo")
          .should eq ["         +         +       +        + foo"]
      end

      it "blanks out regex literals" do
        scan("foo =~ /bar/imx").should eq ["foo =~         "]
        scan("foo(/bar/)").should eq ["foo(     )"]
      end

      it "keeps the division and modulo operators" do
        scan("a / b / c").should eq ["a / b / c"]
        scan("a % b").should eq ["a % b"]
        scan("a.b? / c / d").should eq ["a.b? / c / d"]
        scan("a // b").should eq ["a // b"]
      end

      it "blanks out heredocs" do
        scan("foo(<<-A, <<-'B')\n  a\n  A\n  \#{b}\n  B\nbar\n")
          .should eq ["foo(    ,       )\n   \n   \n      \n   \nbar\n"]
      end

      it "keeps the state between the macro literals" do
        scan(%(foo "bar), %(baz" # qux), "quux\ncorge")
          .should eq ["foo     ", "          ", "    \ncorge"]
      end

      it "joins the `#` and `{` of an interpolation split by the macro lexer" do
        scan("/", "#", "{foo}/").should eq [" ", " ", " foo  "]
      end

      it "ends unterminated char literals at the end of the line" do
        scan("foo '\nbar").should eq ["foo  \nbar"]
      end
    end

    describe "#after_value!" do
      it "treats the following `/` as the division operator" do
        scanner = MacroCodeScanner.new
        scanner.scan("a = ")
        scanner.after_value!
        scanner.scan(" / b / c").should eq " / b / c"
      end
    end

    describe "#clone" do
      it "doesn't share the state with the original scanner" do
        scanner = MacroCodeScanner.new
        scanner.scan(%(foo "))

        scanner.clone.scan(%(bar" baz)).should eq "     baz"
        scanner.scan(%(qux" quux)).should eq "     quux"
      end
    end
  end
end
