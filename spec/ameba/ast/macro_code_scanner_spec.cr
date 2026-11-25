require "../../spec_helper"

private def scan(*literals : String) : Array(String)
  scanner = Ameba::AST::MacroCodeScanner.new
  literals.to_a { |literal| scanner.scan(literal) }
end

# Collects the local variables, skipping the macro code
private class LocalVariables < Crystal::Visitor
  getter vars = [] of Crystal::Var

  def visit(node : Crystal::Var)
    @vars << node
    true
  end

  def visit(node : Crystal::Macro | Crystal::MacroExpression | Crystal::MacroIf | Crystal::MacroFor | Crystal::MacroVerbatim)
    false
  end

  def visit(node : Crystal::ASTNode)
    true
  end
end

# Returns the locations of the local variables within *source*
# blanked out by the scanner, when scanned as a single macro literal
private def blanked_variables(source : String) : Array(String)
  lines = source.lines
  scanned = Ameba::AST::MacroCodeScanner.new.scan(source).lines

  visitor = LocalVariables.new
  Crystal::Parser.new(source).parse.accept(visitor)

  visitor.vars.compact_map do |var|
    next unless location = var.location

    line_index, column_index = location.line_number - 1, location.column_number - 1
    name = var.name
    # Skips the variables, whose (byte-based) column doesn't match the code
    next unless lines[line_index]?.try(&.[column_index, name.size]?) == name
    next if scanned[line_index]?.try(&.[column_index, name.size]?) == name

    "#{location.line_number}:#{location.column_number} `#{name}`"
  end
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
        scan(":foo? + :foo! + :foo= + baz").should eq ["      +       +       + baz"]
        scan("{:foo=>a, :bar==b, :baz!=c}").should eq ["{    =>a,     ==b,     !=c}"]
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

      it "keeps the division operator following an identifier" do
        scan("a /b").should eq ["a /b"]
        scan("a /b\nc / d").should eq ["a /b\nc / d"]
        scan("a /b / c").should eq ["a /b / c"]
      end

      it "blanks out regex literals following an identifier" do
        scan("foo /a/").should eq ["foo    "]
        scan("foo /a\\/b/").should eq ["foo       "]
      end

      it "keeps the operators following a value" do
        scan("@a /b/ c").should eq ["@a /b/ c"]
        scan("@@a /b/ c").should eq ["@@a /b/ c"]
        scan("$a /b/ c").should eq ["$a /b/ c"]
        scan("A /b/ c").should eq ["A /b/ c"]
        scan("A::B /b/ c").should eq ["A::B /b/ c"]
        scan("1.5 /b/ c").should eq ["1.5 /b/ c"]
        scan(":a /b/ c").should eq ["   /b/ c"]
        scan("@a %(b) c").should eq ["@a %(b) c"]
        scan("self /b/ c").should eq ["self /b/ c"]
        scan("nil %(b) c").should eq ["nil %(b) c"]
        scan("(a) /b/ c").should eq ["(a) /b/ c"]
        scan(%("a" /b/ c)).should eq ["    /b/ c"]
      end

      it "blanks out the literals following a method call or a keyword" do
        scan("a.b /c / d").should eq ["a.b      d"]
        scan("a&.b /c/").should eq ["a&.b    "]
        scan("A::b /c/").should eq ["A::b    "]
        scan("a.split /, / if b\nc").should eq ["a.split      if b\nc"]
        scan("when /a / then b").should eq ["when      then b"]
        scan("1..a /b").should eq ["1..a /b"]
        scan("a? /b/").should eq ["a?    "]
        scan("a.b! %(c)").should eq ["a.b!     "]
      end

      it "tells the operand apart from the previously scanned literals" do
        scan("puts", %( %r{a\#{b}})).should eq ["puts", "       b  "]
        scan("puts", " /a/").should eq ["puts", "    "]
        scan("@a", " /b/ c").should eq ["@a", " /b/ c"]
        scan("a.b", " ", " /c/").should eq ["a.b", " ", "    "]
      end

      it "keeps operators used as names" do
        scan("def /(other)\n  a / other / b\nend").should eq ["def /(other)\n  a / other / b\nend"]
        scan("def %(other); end").should eq ["def %(other); end"]
        scan("def `(command); end").should eq ["def `(command); end"]
        scan("def self./(other); a / b; end").should eq ["def self./(other); a / b; end"]
        scan("reduce(:/) + a / b").should eq ["reduce(:/) + a / b"]
        scan("a./(b) + c / d").should eq ["a./(b) + c / d"]
        scan("undef_foo /a/").should eq ["undef_foo    "]
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

    describe "#ambiguous?" do
      it "returns true if the literal has a division operator, which might start a regex" do
        scanner = MacroCodeScanner.new

        # the line of `a /b` might continue after a macro expression
        {"a /b / c", "a /b", "a /", "a.b /"}.each do |literal|
          scanner.scan(literal)
          scanner.ambiguous?.should be_true
        end

        {"a /b\n", "a /b/ c", "a %(b)", "a.b /c / d", "@a /b / c", "a / b / c"}.each do |literal|
          scanner.scan(literal)
          scanner.ambiguous?.should be_false
        end
      end
    end

    describe "#flipped" do
      it "reads the ambiguous `/` of the next literal as regex literals" do
        scanner = MacroCodeScanner.new
        flipped = scanner.flipped
        flipped.scan("foo /a\#{b} / c").should eq "foo     b    c"
        flipped.scan("d /e / f").should eq "d /e / f"
        scanner.scan("foo /a\#{b} / c").should eq "foo /a        "
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

    # Ameba's own sources serve as a corpus of real-world code, which no local
    # variable should be blanked out of - that would hide its references
    it "keeps the local variables of the Ameba sources intact" do
      # Glob patterns require `/` as a path separator, also on Windows
      files = Dir.glob(Path[__DIR__, "..", "..", "..", "src", "**", "*.cr"].expand.to_posix)
      files.should_not be_empty

      blanked = files.flat_map do |file|
        blanked_variables(File.read(file)).map { |var| "#{Path[file].relative_to(Dir.current)}:#{var}" }
      end
      blanked.should be_empty
    end
  end
end
